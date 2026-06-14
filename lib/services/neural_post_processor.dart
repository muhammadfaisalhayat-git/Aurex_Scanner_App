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

    // 3. Pairing Logic with high horizontal bias and "Same-Line" boost
    final List<_Pairing> potentialPairs = [];
    for (var candidate in candidates) {
      for (var anchor in anchors) {
        final score = _calculateRelationshipScore(anchor, candidate, imageSize);
        if (score > 0.2) {
          potentialPairs.add(_Pairing(anchor, candidate, score));
        }
      }
    }

    // Sort by descending score to pick absolute best matches first
    potentialPairs.sort((a, b) => b.score.compareTo(a.score));

    final Set<String> matchedAnchors = {};
    final Set<Rect> matchedCandidates = {};

    for (var pair in potentialPairs) {
      // Use block center as part of key for uniqueness
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
    final lower = text.toLowerCase();
    return ["variety", "product", "kind", "crop", "item", "exported", "india"].any((l) => lower == l);
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
       // Robust word-boundary check
       if (text == kw || text.startsWith("$kw ") || text.startsWith("$kw:") || text.contains(" $kw")) {
         return true;
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
            val = TextParser.normalizeDate(val);
            break;
          }
        }

        // Weight Check
        if (!isDate && TextParser.unitRegex.hasMatch(text)) {
           isWeight = true;
        }

        candidates.add(_ValueCandidate(val, line.boundingBox, line.text, isDate, isWeight));
      }
    }
    return candidates;
  }

  double _calculateRelationshipScore(_Anchor anchor, _ValueCandidate candidate, Size imgSize) {
    final aRect = anchor.block.boundingBox;
    final cRect = candidate.boundingBox;
    final aText = anchor.block.text.toLowerCase();
    final cLineText = candidate.fullLineText.toLowerCase();

    final double aCenterY = aRect.top + (aRect.height / 2);
    final double cCenterY = cRect.top + (cRect.height / 2);
    final double dy = (aCenterY - cCenterY).abs() / imgSize.height;
    
    double score = 0.0;

    // RULE 1: SELF-CONTAINMENT (ULTRA HIGH BOOST)
    // If the candidate's line text already contains the anchor's keywords, it's a direct hit!
    if (candidate.isDate) {
      if (anchor.type == _AnchorType.mfg && _isStrictKeywordMatch(cLineText, TextParser.mfgKeywords)) {
        return 0.99; // Strongest possible match
      }
      if (anchor.type == _AnchorType.exp && _isStrictKeywordMatch(cLineText, TextParser.expKeywords)) {
        return 0.99;
      }
    }

    // RULE 2: TABLE LAYOUT (Horizontal proximity)
    if ((aCenterY - cCenterY).abs() < aRect.height * 1.2) {
      if (cRect.left > aRect.left) { 
         double dx = (cRect.left - aRect.right).abs() / imgSize.width;
         score = 1.0 - (dx * 3.0); 
      } else if (cRect.right < aRect.left) { 
         double dx = (aRect.left - cRect.right).abs() / imgSize.width;
         score = 0.95 - (dx * 3.0);
      }
    } 
    // RULE 3: BELOW LAYOUT (Vertical proximity)
    else if (cRect.top > aRect.top && (cRect.left - aRect.left).abs() < aRect.width * 0.8) {
      score = 0.5 - (dy * 4.0);
    }

    return score.clamp(0.0, 1.0);
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
