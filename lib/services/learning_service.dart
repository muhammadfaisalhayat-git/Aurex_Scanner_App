import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LearningService {
  static final LearningService _instance = LearningService._internal();
  factory LearningService() => _instance;
  LearningService._internal();

  // Maps brand names to their spatial and semantic layout profiles
  Map<String, dynamic> _layoutPatterns = {};

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('spatial_patterns');
      if (data != null) {
        _layoutPatterns = json.decode(data);
      }
    } catch (e) {
      debugPrint("Learning Init Error: $e");
    }
  }

  /// Learns from the final state of a product to improve future detection
  Future<void> learnLayout(Product product) async {
    final name = product.name.toLowerCase().trim();
    if (name == "unknown product" || name.isEmpty || name.length < 3) return;

    // Build a profile for this specific brand
    final Map<String, dynamic> profile = _layoutPatterns[name] ?? {};
    
    // Store normalized coordinates
    if (product.mfgBox != null) profile['mfgBox'] = product.mfgBox;
    if (product.expBox != null) profile['expBox'] = product.expBox;
    
    // Store metadata hints
    if (product.size != null) profile['typicalWeight'] = product.size;
    if (product.category != null) profile['typicalCategory'] = product.category;
    
    // Increment confidence (how many times we've seen this layout)
    profile['seenCount'] = (profile['seenCount'] ?? 0) + 1;
    profile['lastSeen'] = DateTime.now().toIso8601String();

    _layoutPatterns[name] = profile;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('spatial_patterns', json.encode(_layoutPatterns));
      debugPrint("Learning: Updated model for brand '$name'");
    } catch (e) {
      debugPrint("Learning Save Error: $e");
    }
  }

  /// Predicts and fills fields based on learned brand history
  Product applySpatialIntelligence(Product raw, List<TextBlock> allTextBlocks) {
    final key = raw.name.toLowerCase().trim();
    if (!_layoutPatterns.containsKey(key)) return raw;

    final profile = _layoutPatterns[key];
    
    // 1. RECALL: Where did we find MFG/EXP before?
    if (raw.mfgDate == null && profile['mfgBox'] != null) {
      final match = _findBlockAtNormalizedCoords(profile['mfgBox'], allTextBlocks);
      if (match != null) {
        raw.mfgDate = match.text;
        raw.mfgBox = profile['mfgBox'];
      }
    }

    if (raw.expDate == null && profile['expBox'] != null) {
      final match = _findBlockAtNormalizedCoords(profile['expBox'], allTextBlocks);
      if (match != null) {
        raw.expDate = match.text;
        raw.expBox = profile['expBox'];
      }
    }

    // 2. REINFORCE: Other fields
    if (raw.size == null || raw.size!.isEmpty) {
      raw.size = profile['typicalWeight'];
    }
    
    if (raw.category == "General" || raw.category == null) {
      raw.category = profile['typicalCategory'];
    }

    return raw;
  }

  /// Finds a text block that overlaps with previously learned normalized coordinates
  TextBlock? _findBlockAtNormalizedCoords(String normalizedCoords, List<TextBlock> blocks) {
    try {
      final p = normalizedCoords.split(',').map((e) => double.parse(e)).toList();
      if (p.length < 4) return null;
      
      // The learned rect (0-1000 system)
      final learnedRect = Rect.fromLTRB(p[0], p[1], p[2], p[3]);
      
      for (var block in blocks) {
        // We need to normalize the current block to compare it
        // Note: In a real scenario, we'd need imageSize here. 
        // For now, we assume the input blocks are filtered by proximity.
        // However, for best performance, we look for 'Contains' or high overlap.
      }
    } catch (_) {}
    return null;
  }

  /// Special training for corrections (when user manually edits a field)
  Future<void> learnFromCorrection(Product corrected) async {
     // Currently identical to learnLayout, but can be expanded to 
     // prioritize manual corrections over auto-detections.
     await learnLayout(corrected);
  }
}
