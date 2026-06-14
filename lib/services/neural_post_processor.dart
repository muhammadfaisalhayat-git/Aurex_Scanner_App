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

    // 3. Neural-Spatial Pairing: Match each candidate to its most likely anchor
    for (var candidate in candidates) {
      _AnchorMatch? bestMatch;
      double maxScore = 0.0;

      for (var anchor in anchors) {
        final score = _calculateRelationshipScore(anchor, candidate, imageSize);
        if (score > maxScore) {
          maxScore = score;
          bestMatch = _AnchorMatch(anchor, score);
        }
      }

      if (bestMatch != null && bestMatch.score > 0.4) {
        switch (bestMatch.anchor.type) {
          case _AnchorType.mfg:
            if (mfgDate == null && candidate.isDate) {
              mfgDate = candidate.text;
              mfgBox = TextParser.formatBox(candidate.boundingBox, imageSize);
            }
            break;
          case _AnchorType.exp:
            if (expDate == null && candidate.isDate) {
              expDate = candidate.text;
              expBox = TextParser.formatBox(candidate.boundingBox, imageSize);
            }
            break;
          case _AnchorType.name:
            if (!candidate.isDate && !candidate.isWeight) name ??= candidate.text;
            break;
          case _AnchorType.size:
            if (candidate.isWeight) size ??= candidate.text;
            break;
        }
      }
    }

    // 4. Fallback for Product Name (Largest clean block)
    if (name == null || name == "Unknown Product") {
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
       if (kw.length <= 4) {
          if (text == kw || text == "$kw:" || text == "$kw.") return true;
       } else {
          if (text.contains(kw)) return true;
       }
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
        
        // Date Check
        for (var pattern in TextParser.datePatterns) {
          if (pattern.hasMatch(text)) {
            isDate = true;
            val = pattern.firstMatch(text)!.group(0)!;
            break;
          }
        }

        // Weight Check
        if (!isDate && TextParser.unitRegex.hasMatch(text)) {
           isWeight = true;
        }

        candidates.add(_ValueCandidate(val, line.boundingBox, isDate, isWeight));
      }
    }
    return candidates;
  }

  double _calculateRelationshipScore(_Anchor anchor, _ValueCandidate candidate, Size imgSize) {
    final aRect = anchor.block.boundingBox;
    final cRect = candidate.boundingBox;

    final double aCenterY = aRect.top + (aRect.height / 2);
    final double cCenterY = cRect.top + (cRect.height / 2);
    final double dy = (aCenterY - cCenterY).abs() / imgSize.height;
    
    double score = 0.0;

    // Horizontal Alignment (Same line boost)
    if ((aCenterY - cCenterY).abs() < aRect.height * 0.9) {
      if (cRect.left > aRect.left) { // Value on right
         double dx = (cRect.left - aRect.right).abs() / imgSize.width;
         score = 1.0 - (dx * 3.0); 
      } else if (cRect.right < aRect.left) { // Value on left (RTL)
         double dx = (aRect.left - cRect.right).abs() / imgSize.width;
         score = 0.9 - (dx * 3.0);
      }
    } 
    // Vertical Alignment (Immediately below boost)
    else if (cRect.top > aRect.top && (cRect.left - aRect.left).abs() < aRect.width * 0.5) {
      score = 0.6 - (dy * 5.0);
    }

    return score.clamp(0.0, 1.0);
  }

  String? _smartNameFallback(List<TextBlock> blocks) {
    if (blocks.isEmpty) return null;
    final topBlocks = blocks.where((b) => b.boundingBox.top < 450).toList();
    if (topBlocks.isEmpty) return null;
    
    topBlocks.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
        .compareTo(a.boundingBox.width * a.boundingBox.height));
    
    for (var b in topBlocks) {
       final t = b.text.toLowerCase();
       if (t.length > 3 && !TextParser.isMetadataBlock(t)) {
         return b.text.split('\n').first;
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
  final bool isDate;
  final bool isWeight;
  _ValueCandidate(this.text, this.boundingBox, this.isDate, this.isWeight);
}

class _AnchorMatch {
  final _Anchor anchor;
  final double score;
  _AnchorMatch(this.anchor, this.score);
}
