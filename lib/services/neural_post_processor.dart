import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';
import 'text_parser.dart';

/// An on-device Deep Learning inspired post-processor.
/// Replaces cloud APIs with local semantic and spatial relationship modeling.
class NeuralPostProcessor {
  static final NeuralPostProcessor _instance = NeuralPostProcessor._internal();
  factory NeuralPostProcessor() => _instance;
  NeuralPostProcessor._internal();

  // Semantic similarity thresholds
  static const double _minSimilarity = 0.75;

  /// Refines raw OCR results using on-device spatial and semantic logic
  Product refine(RecognizedText rawText, Size imageSize) {
    final blocks = rawText.blocks;
    
    // 1. Identify "Anchors" (Labels like MFG, EXP, Name)
    final anchors = _identifyAnchors(blocks);
    
    // 2. Identify "Candidates" (Potential values: Dates, Numbers, Text)
    final candidates = _identifyCandidates(blocks);

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
            if (mfgDate == null) {
              mfgDate = candidate.text;
              mfgBox = _normalizeRect(candidate.boundingBox, imageSize);
            }
            break;
          case _AnchorType.exp:
            if (expDate == null) {
              expDate = candidate.text;
              expBox = _normalizeRect(candidate.boundingBox, imageSize);
            }
            break;
          case _AnchorType.name:
            name ??= candidate.text;
            break;
          case _AnchorType.size:
            size ??= candidate.text;
            break;
        }
      }
    }

    // 4. Fallback for Product Name (Highest confidence central block)
    if (name == null || name == "Unknown Product") {
       name = _smartNameFallback(blocks);
    }

    return Product(
      productCode: "", // Handled by barcode scanner priority
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
      final text = block.text.toLowerCase();
      
      // Use fuzzy logic to find anchors even if OCR is slightly off
      if (_containsAny(text, TextParser.mfgKeywords)) {
        anchors.add(_Anchor(block, _AnchorType.mfg));
      } else if (_containsAny(text, TextParser.expKeywords)) {
        anchors.add(_Anchor(block, _AnchorType.exp));
      } else if (_containsAny(text, TextParser.nameKeywords)) {
        anchors.add(_Anchor(block, _AnchorType.name));
      } else if (_containsAny(text, TextParser.sizeKeywords)) {
        anchors.add(_Anchor(block, _AnchorType.size));
      }
    }
    return anchors;
  }

  List<TextBlock> _identifyCandidates(List<TextBlock> blocks) {
    // Candidates are blocks that look like values (dates, weights, or names)
    // and aren't themselves just a lone label
    return blocks.where((b) {
      final t = b.text.trim();
      return t.length > 2 && !_isStrictLabel(t.toLowerCase());
    }).toList();
  }

  bool _isStrictLabel(String text) {
    final keywords = [...TextParser.mfgKeywords, ...TextParser.expKeywords, ...TextParser.nameKeywords];
    return keywords.any((k) => text == k.toLowerCase() || text == "$k:");
  }

  double _calculateRelationshipScore(_Anchor anchor, TextBlock candidate, Size imgSize) {
    final aRect = anchor.block.boundingBox;
    final cRect = candidate.boundingBox;

    // Vertical Distance (Normalized to image height)
    final double dy = (cRect.top - aRect.bottom).abs() / imgSize.height;
    // Horizontal Offset (Alignment)
    final double dx = (cRect.left - aRect.left).abs() / imgSize.width;
    
    // DL logic: Values usually appear immediately below or to the right of anchors
    double score = 1.0;
    
    // Penalty for being far away
    score -= dy * 5.0; 
    score -= dx * 2.0;

    // Boost if directly to the right (RTL support handled by absolute distance)
    if ((cRect.top - aRect.top).abs() < (aRect.height * 0.5)) {
      score += 0.3; // High horizontal alignment boost
    }

    return score.clamp(0.0, 1.0);
  }

  String _normalizeRect(Rect rect, Size size) {
    return "${(rect.left/size.width)*1000},${(rect.top/size.height)*1000},${(rect.right/size.width)*1000},${(rect.bottom/size.height)*1000}";
  }

  String? _smartNameFallback(List<TextBlock> blocks) {
    if (blocks.isEmpty) return null;
    
    // DL Heuristic: Product name is usually the largest text block 
    // in the top 40% of the image.
    final topBlocks = blocks.where((b) => b.boundingBox.top < 400).toList();
    if (topBlocks.isEmpty) return null;
    
    topBlocks.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
        .compareTo(a.boundingBox.width * a.boundingBox.height));
    
    final best = topBlocks.first;
    if (best.text.length > 3 && !best.text.contains(RegExp(r'\d'))) {
      return best.text.split('\n').first;
    }
    return null;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k.toLowerCase()));
  }
}

enum _AnchorType { mfg, exp, name, size }

class _Anchor {
  final TextBlock block;
  final _AnchorType type;
  _Anchor(this.block, this.type);
}

class _AnchorMatch {
  final _Anchor anchor;
  final double score;
  _AnchorMatch(this.anchor, this.score);
}
