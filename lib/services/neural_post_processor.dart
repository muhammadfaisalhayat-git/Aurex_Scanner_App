import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';
import 'text_parser.dart';

class NeuralPostProcessor {
  static final NeuralPostProcessor _instance = NeuralPostProcessor._internal();
  factory NeuralPostProcessor() => _instance;
  NeuralPostProcessor._internal();

  /// Refines product data by aggregating information from multiple captured images
  Product refineMulti(List<RecognizedText> allRawTexts, List<Size> allSizes) {
    String? finalName;
    String? finalMfg;
    String? finalExp;
    String? finalMfgBox;
    String? finalExpBox;
    String? finalSize;
    String finalQty = "1";

    for (int i = 0; i < allRawTexts.length; i++) {
      final p = refine(allRawTexts[i], allSizes[i]);
      
      // Merge strategy: Keep the first solid detection
      if (finalName == null || finalName == "Unknown Product") {
        if (p.name != "Unknown Product") finalName = p.name;
      }
      
      finalMfg ??= p.mfgDate;
      finalMfgBox ??= p.mfgBox;
      
      finalExp ??= p.expDate;
      finalExpBox ??= p.expBox;
      
      finalSize ??= p.size;
      if (finalQty == "1" && p.quantity != "1") finalQty = p.quantity;
    }

    return Product(
      productCode: "",
      name: finalName ?? "Unknown Product",
      mfgDate: finalMfg,
      expDate: finalExp,
      mfgBox: finalMfgBox,
      expBox: finalExpBox,
      size: finalSize,
      quantity: finalQty,
    );
  }

  Product refine(RecognizedText rawText, Size imageSize) {
    // 1. Pre-process: Split merged lines by whitespace to handle multi-column blocks
    final List<_StructuralLine> allLines = _extractStructuralLines(rawText);

    // 2. Identify "Anchors" (Labels like MFG, EXP, Name)
    final anchors = _identifyAnchors(allLines);
    
    // 3. Extract potential values with strict validation
    final List<_ValueCandidate> candidates = _extractValidatedCandidates(allLines);

    String? name;
    String? mfgDate;
    String? expDate;
    String? mfgBox;
    String? expBox;
    String? size;

    // 4. Structural Table Engine: Global Proximity and Alignment Scoring
    final List<_Pairing> potentialPairs = [];
    for (var candidate in candidates) {
      for (var anchor in anchors) {
        final score = _calculateStructuralScore(anchor, candidate, imageSize);
        if (score > 0.15) {
          potentialPairs.add(_Pairing(anchor, candidate, score));
        }
      }
    }

    potentialPairs.sort((a, b) => b.score.compareTo(a.score));

    final Set<String> matchedAnchors = {};
    final Set<Rect> matchedCandidates = {};

    for (var pair in potentialPairs) {
      final anchorId = "${pair.anchor.type}_${pair.anchor.boundingBox.center}";
      final candidateId = pair.candidate.boundingBox;

      if (matchedAnchors.contains(anchorId) || matchedCandidates.contains(candidateId)) {
        continue;
      }

      switch (pair.anchor.type) {
        case _AnchorType.mfg:
          if (pair.candidate.isDate) {
            mfgDate = pair.candidate.text;
            mfgBox = TextParser.formatBox(pair.candidate.boundingBox, imageSize);
            matchedAnchors.add(anchorId); matchedCandidates.add(candidateId);
          }
          break;
        case _AnchorType.exp:
          if (pair.candidate.isDate) {
            expDate = pair.candidate.text;
            expBox = TextParser.formatBox(pair.candidate.boundingBox, imageSize);
            matchedAnchors.add(anchorId); matchedCandidates.add(candidateId);
          }
          break;
        case _AnchorType.name:
          if (!pair.candidate.isDate && !pair.candidate.isWeight) {
             name = pair.candidate.text;
             matchedAnchors.add(anchorId); matchedCandidates.add(candidateId);
          }
          break;
        case _AnchorType.size:
          if (pair.candidate.isWeight) {
             size = pair.candidate.text;
             matchedAnchors.add(anchorId); matchedCandidates.add(candidateId);
          }
          break;
      }
    }

    // 5. Fallback for Product Name (Largest clean block in top area)
    if (name == null || name == "Unknown Product" || _isGenericLabel(name)) {
       name = _smartNameFallback(allLines);
    }

    return Product(
      productCode: "", 
      name: name ?? "Unknown Product",
      mfgDate: mfgDate,
      expDate: expDate,
      mfgBox: mfgBox,
      expBox: expBox,
      size: size,
    );
  }

  /// Splits text lines with large horizontal gaps into separate structural elements.
  /// This handles OCR "merging" multiple columns into one line.
  List<_StructuralLine> _extractStructuralLines(RecognizedText raw) {
    final List<_StructuralLine> structuralLines = [];
    for (var block in raw.blocks) {
      for (var line in block.lines) {
        final text = line.text;
        // Search for double-spaces or large gaps (indicative of table columns)
        if (text.contains("  ")) {
           final parts = text.split(RegExp(r'\s{2,}'));
           double currentLeft = line.boundingBox.left;
           final double charWidth = line.boundingBox.width / text.length;

           for (var part in parts) {
             if (part.trim().isEmpty) {
                currentLeft += (part.length * charWidth);
                continue;
             }
             final double partWidth = part.length * charWidth;
             final partRect = Rect.fromLTWH(currentLeft, line.boundingBox.top, partWidth, line.boundingBox.height);
             structuralLines.add(_StructuralLine(part.trim(), partRect));
             currentLeft += (part.length * charWidth);
           }
        } else {
          structuralLines.add(_StructuralLine(line.text, line.boundingBox));
        }
      }
    }
    return structuralLines;
  }

  bool _isGenericLabel(String text) {
    final lower = text.toLowerCase().trim();
    return ["variety", "product", "kind", "crop", "item", "exported", "india", "lot", "treatment", "exp", "mfg"].any((l) => lower.contains(l));
  }

  List<_Anchor> _identifyAnchors(List<_StructuralLine> lines) {
    final List<_Anchor> anchors = [];
    for (var line in lines) {
      final text = line.text.toLowerCase().trim();
      if (_isStrictKeywordMatch(text, TextParser.mfgKeywords)) {
        anchors.add(_Anchor(line.boundingBox, _AnchorType.mfg, line.text));
      } else if (_isStrictKeywordMatch(text, TextParser.expKeywords)) {
        anchors.add(_Anchor(line.boundingBox, _AnchorType.exp, line.text));
      } else if (_isStrictKeywordMatch(text, TextParser.nameKeywords)) {
        anchors.add(_Anchor(line.boundingBox, _AnchorType.name, line.text));
      } else if (_isStrictKeywordMatch(text, TextParser.sizeKeywords)) {
        anchors.add(_Anchor(line.boundingBox, _AnchorType.size, line.text));
      }
    }
    return anchors;
  }

  bool _isStrictKeywordMatch(String text, List<String> keywords) {
    for (var k in keywords) {
       final kw = k.toLowerCase();
       // Robust word-boundary check + colon support for Arabic
       if (text == kw || text == "$kw:" || text.startsWith("$kw ") || text.startsWith("$kw:") || text.startsWith("$kw.") || text.endsWith(" $kw") || text.endsWith(":$kw")) {
         return true;
       }
       if (text.contains("\n$kw") || text.contains("$kw\n")) return true;
    }
    return false;
  }

  List<_ValueCandidate> _extractValidatedCandidates(List<_StructuralLine> lines) {
    final List<_ValueCandidate> candidates = [];
    for (var line in lines) {
      final text = line.text.trim();
      if (text.length < 3) continue;

      bool isDate = false;
      bool isWeight = false;
      String val = text;
      
      for (var pattern in TextParser.datePatterns) {
        if (pattern.hasMatch(text)) {
          isDate = true;
          val = pattern.firstMatch(text)!.group(0)!;
          val = TextParser.normalizeDate(val);
          break;
        }
      }

      if (!isDate && TextParser.unitRegex.hasMatch(text)) {
         isWeight = true;
      }

      candidates.add(_ValueCandidate(val, line.boundingBox, line.text, isDate, isWeight));
    }
    return candidates;
  }

  double _calculateStructuralScore(_Anchor anchor, _ValueCandidate candidate, Size imgSize) {
    final aRect = anchor.boundingBox;
    final cRect = candidate.boundingBox;
    final cLineText = candidate.fullLineText.toLowerCase();

    final double aCenterX = aRect.left + (aRect.width / 2);
    final double cCenterX = cRect.left + (cRect.width / 2);
    final double aCenterY = aRect.top + (aRect.height / 2);
    final double cCenterY = cRect.top + (cRect.height / 2);
    
    final double dxNorm = (aCenterX - cCenterX).abs() / imgSize.width;
    final double dyNorm = (aCenterY - cCenterY).abs() / imgSize.height;
    
    // PATTERN 1: INLINE (Direct Line Match)
    if (candidate.isDate) {
      if (anchor.type == _AnchorType.mfg && _isStrictKeywordMatch(cLineText, TextParser.mfgKeywords)) return 0.99;
      if (anchor.type == _AnchorType.exp && _isStrictKeywordMatch(cLineText, TextParser.expKeywords)) return 0.99;
    }

    // PATTERN 2: COLUMNAR PROJECTON (Grid Match)
    // Label on Top, Value Below - Projecting the anchor's column vertically
    if (cRect.top > aRect.top && dyNorm < 0.25) {
       // Check if centers are horizontally aligned (within column bounds)
       final double hOverlap = _calculateHorizontalOverlap(aRect, cRect);
       if (hOverlap > 0.3 || (aCenterX - cCenterX).abs() < aRect.width * 0.5) {
          double gridScore = 0.95 - (dyNorm * 2.5);
          // Boost if centers are very close (highly likely in seed grids)
          if ((aCenterX - cCenterX).abs() < aRect.width * 0.15) gridScore += 0.05;
          return gridScore.clamp(0.0, 1.0);
       }
    }

    // PATTERN 3: ROW PROJECTON (Label on Left, Value on Right)
    if ((aCenterY - cCenterY).abs() < aRect.height * 1.5) {
      if (cRect.left > aRect.left) { 
         return (1.0 - (dxNorm * 2.5)).clamp(0.0, 1.0); 
      } else if (cRect.right < aRect.left) { 
         // RTL Support
         return (0.95 - (dxNorm * 2.5)).clamp(0.0, 1.0);
      }
    } 

    return 0.0;
  }

  double _calculateHorizontalOverlap(Rect r1, Rect r2) {
    final double left = r1.left > r2.left ? r1.left : r2.left;
    final double right = r1.right < r2.right ? r1.right : r2.right;
    if (left >= right) return 0.0;
    final double overlapWidth = right - left;
    final double minWidth = r1.width < r2.width ? r1.width : r2.width;
    return overlapWidth / minWidth;
  }

  String? _smartNameFallback(List<_StructuralLine> lines) {
    if (lines.isEmpty) return null;
    final topLines = lines.where((l) => l.boundingBox.top < 500).toList();
    topLines.sort((a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(a.boundingBox.width * a.boundingBox.height));
    
    for (var l in topLines) {
       final t = l.text.toLowerCase().trim();
       if (t.length > 3 && !TextParser.isMetadataBlock(t) && !_isGenericLabel(t)) {
         return l.text.split('\n').first.trim();
       }
    }
    return null;
  }
}

enum _AnchorType { mfg, exp, name, size }

class _StructuralLine {
  final String text;
  final Rect boundingBox;
  _StructuralLine(this.text, this.boundingBox);
}

class _Anchor {
  final Rect boundingBox;
  final _AnchorType type;
  final String text;
  _Anchor(this.boundingBox, this.type, this.text);
}

class _ValueCandidate {
  final String text;
  final Rect boundingBox;
  final String fullLineText;
  final bool isDate;
  final bool isWeight;
  _ValueCandidate(this.text, this.boundingBox, this.fullLineText, this.isDate, this.isWeight);
}

class _Pairing {
  final _Anchor anchor;
  final _ValueCandidate candidate;
  final double score;
  _Pairing(this.anchor, this.candidate, this.score);
}
