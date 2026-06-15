import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';
import 'text_parser.dart';

class NeuralPostProcessor {
  static final NeuralPostProcessor _instance = NeuralPostProcessor._internal();
  factory NeuralPostProcessor() => _instance;
  NeuralPostProcessor._internal();

  Product refine(RecognizedText rawText, Size imageSize) {
    final blocks = rawText.blocks;
    
    // 1. Identify "Anchors" (Labels like MFG, EXP, Name)
    final anchors = _identifyAnchors(blocks);
    
    // 2. Extract potential values with strict validation
    final List<_ValueCandidate> candidates = _extractValidatedCandidates(rawText);

    String? name;
    String? mfgDate;
    String? expDate;
    String? mfgBox;
    String? expBox;
    String? size;

    // 3. Pairing Logic with Universal Table Pattern Weights
    final List<_Pairing> potentialPairs = [];
    for (var candidate in candidates) {
      for (var anchor in anchors) {
        final score = _calculateUniversalRelationshipScore(anchor, candidate, imageSize);
        if (score > 0.15) {
          potentialPairs.add(_Pairing(anchor, candidate, score));
        }
      }
    }

    // Sort by descending score to pick absolute best matches first
    potentialPairs.sort((a, b) => b.score.compareTo(a.score));

    final Set<String> matchedAnchors = {};
    final Set<Rect> matchedCandidates = {};

    for (var pair in potentialPairs) {
      final anchorId = "${pair.anchor.type}_${pair.anchor.block.boundingBox.center}";
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

    // 4. Enhanced Fallback for Product Name
    if (name == null || name == "Unknown Product" || _isGenericLabel(name)) {
       name = _smartNameFallback(blocks);
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

  bool _isGenericLabel(String text) {
    final lower = text.toLowerCase().trim();
    return ["variety", "product", "kind", "crop", "item", "exported", "india", "lot", "treatment", "exp", "mfg"].any((l) => lower.contains(l));
  }

  List<_Anchor> _identifyAnchors(List<TextBlock> blocks) {
    final List<_Anchor> anchors = [];
    for (var block in blocks) {
      final text = block.text.toLowerCase().trim();
      if (_isStrictKeywordMatch(text, TextParser.mfgKeywords)) {
        anchors.add(_Anchor(block, _AnchorType.mfg));
      } else if (_isStrictKeywordMatch(text, TextParser.expKeywords)) {
        anchors.add(_Anchor(block, _AnchorType.exp));
      } else if (_isStrictKeywordMatch(text, TextParser.nameKeywords)) {
        anchors.add(_Anchor(block, _AnchorType.name));
      } else if (_isStrictKeywordMatch(text, TextParser.sizeKeywords)) {
        anchors.add(_Anchor(block, _AnchorType.size));
      }
    }
    return anchors;
  }

  bool _isStrictKeywordMatch(String text, List<String> keywords) {
    for (var k in keywords) {
       final kw = k.toLowerCase();
       if (text == kw || text.startsWith("$kw ") || text.startsWith("$kw:") || text.startsWith("$kw.")) return true;
       if (text.contains("\n$kw") || text.contains("$kw\n")) return true;
    }
    return false;
  }

  List<_ValueCandidate> _extractValidatedCandidates(RecognizedText raw) {
    final List<_ValueCandidate> candidates = [];
    for (var block in raw.blocks) {
      for (var line in block.lines) {
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
    }
    return candidates;
  }

  double _calculateUniversalRelationshipScore(_Anchor anchor, _ValueCandidate candidate, Size imgSize) {
    final aRect = anchor.block.boundingBox;
    final cRect = candidate.boundingBox;
    final cLineText = candidate.fullLineText.toLowerCase();

    final double aCenterX = aRect.left + (aRect.width / 2);
    final double cCenterX = cRect.left + (cRect.width / 2);
    final double aCenterY = aRect.top + (aRect.height / 2);
    final double cCenterY = cRect.top + (cRect.height / 2);
    
    final double dxNorm = (aCenterX - cCenterX).abs() / imgSize.width;
    final double dyNorm = (aCenterY - cCenterY).abs() / imgSize.height;
    
    // PATTERN 1: INLINE (Direct Line Match)
    // Label and Value are merged into one line by the OCR engine.
    if (candidate.isDate) {
      if (anchor.type == _AnchorType.mfg && _isStrictKeywordMatch(cLineText, TextParser.mfgKeywords)) return 0.99;
      if (anchor.type == _AnchorType.exp && _isStrictKeywordMatch(cLineText, TextParser.expKeywords)) return 0.99;
    }

    // PATTERN 2: HORIZONTAL TABLE (Label-Left, Value-Right)
    // Most common in retail and formal documents.
    if ((aCenterY - cCenterY).abs() < aRect.height * 1.2) {
      if (cRect.left > aRect.left) { 
         double score = 1.0 - (dxNorm * 2.5);
         // Check for separators like ":" between them
         return score.clamp(0.0, 1.0); 
      }
    }

    // PATTERN 3: COLUMNAR HEADER (Label-Top, Value-Below)
    // Common in industrial labels and spreadsheets.
    if (cRect.top > aRect.top && dyNorm < 0.15) {
       // High boost if horizontally centered with each other
       if ((aCenterX - cCenterX).abs() < aRect.width * 0.5) {
          double columnarScore = 0.85 - (dyNorm * 2.0);
          if ((aCenterX - cCenterX).abs() < aRect.width * 0.15) columnarScore += 0.1;
          return columnarScore.clamp(0.0, 1.0);
       }
    }

    // PATTERN 4: ARABIC/RTL TABLE (Value-Left, Label-Right)
    // Specific for Arabic-first labels.
    if ((aCenterY - cCenterY).abs() < aRect.height * 1.2) {
      if (cRect.right < aRect.left) {
         return (0.95 - (dxNorm * 2.5)).clamp(0.0, 1.0);
      }
    } 

    return 0.0;
  }

  String? _smartNameFallback(List<TextBlock> blocks) {
    if (blocks.isEmpty) return null;
    final topBlocks = blocks.where((b) => b.boundingBox.top < 500).toList();
    topBlocks.sort((a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(a.boundingBox.width * a.boundingBox.height));
    
    for (var b in topBlocks) {
       final t = b.text.toLowerCase().trim();
       if (t.length > 3 && !TextParser.isMetadataBlock(t) && !_isGenericLabel(t)) {
         return b.text.split('\n').first.trim();
       }
    }
    return null;
  }
}

enum _AnchorType { mfg, exp, name, size }

class _Anchor {
  final TextBlock block;
  final _AnchorType type;
  _Anchor(this.block, this.type);
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
