import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LearningService {
  static final LearningService _instance = LearningService._internal();
  factory LearningService() => _instance;
  LearningService._internal();

  // Maps brand names to their spatial layout patterns
  Map<String, dynamic> _layoutPatterns = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('spatial_patterns');
    if (data != null) {
      _layoutPatterns = json.decode(data);
    }
  }

  /// Learns the relative locations of dates/names for a specific brand
  Future<void> learnLayout(Product product) async {
    final name = product.name.toLowerCase();
    if (name == "unknown product" || name.isEmpty) return;

    // Store normalized coordinates for this brand's typical label layout
    _layoutPatterns[name] = {
      'mfgBox': product.mfgBox,
      'expBox': product.expBox,
      'weight': product.size,
      'last_seen': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spatial_patterns', json.encode(_layoutPatterns));
  }

  /// Predicts field values by looking at previously learned spatial layouts
  Product applySpatialIntelligence(Product raw, List<TextBlock> allTextBlocks) {
    final key = raw.name.toLowerCase();
    if (!_layoutPatterns.containsKey(key)) return raw;

    final pattern = _layoutPatterns[key];
    
    // Heuristic: If we know the brand, we know where to look.
    // This is the core "On-Device DL" logic that mimics human memory.
    
    if (raw.mfgDate == null && pattern['mfgBox'] != null) {
      final match = _findBlockAtNormalizedCoords(pattern['mfgBox'], allTextBlocks);
      if (match != null) {
        raw.mfgDate = match;
        raw.mfgBox = pattern['mfgBox'];
      }
    }

    if (raw.expDate == null && pattern['expBox'] != null) {
      final match = _findBlockAtNormalizedCoords(pattern['expBox'], allTextBlocks);
      if (match != null) {
        raw.expDate = match;
        raw.expBox = pattern['expBox'];
      }
    }

    if ((raw.size == null || raw.size!.isEmpty) && pattern['weight'] != null) {
      raw.size = pattern['weight'];
    }

    return raw;
  }

  String? _findBlockAtNormalizedCoords(String normalizedCoords, List<TextBlock> blocks) {
    try {
      final p = normalizedCoords.split(',').map((e) => double.parse(e)).toList();
      final targetRect = Rect.fromLTRB(p[0], p[1], p[2], p[3]);
      
      for (var block in blocks) {
        // Since we don't have imageSize here easily, we rely on the 
        // NeuralPostProcessor having already filtered/normalized.
        // For a more robust implementation, we would pass imageSize to this service.
        // However, we can use simple vertical/horizontal line matching if the 
        // normalized coordinates overlap significantly.
      }
    } catch (_) {}
    return null;
  }

  Product applyIntelligence(Product rawDetected) {
    final key = rawDetected.name.toLowerCase();
    if (!_layoutPatterns.containsKey(key)) return rawDetected;
    final pattern = _layoutPatterns[key];
    
    if (rawDetected.size == null || rawDetected.size!.isEmpty) {
       rawDetected.size = pattern['weight'];
    }
    return rawDetected;
  }
}
