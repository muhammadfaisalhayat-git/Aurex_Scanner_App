import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class LearningService {
  static final LearningService _instance = LearningService._internal();
  factory LearningService() => _instance;
  LearningService._internal();

  // Pattern library: maps brand/crop name to their specific label layout info
  // This is used for "self-learning" based on user corrections.
  Map<String, dynamic> _learnedPatterns = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('learned_patterns');
    if (data != null) {
      _learnedPatterns = json.decode(data);
    }
  }

  /// Records a successful data extraction/correction to improve future accuracy.
  /// This is the core of the "Self-Learning" mechanism.
  Future<void> learnFromCorrection(Product correctedProduct) async {
    final name = correctedProduct.name.toLowerCase();
    if (name == "unknown product" || name.isEmpty) return;

    // Save metadata about how this specific product label is structured
    _learnedPatterns[name] = {
      'weight': correctedProduct.size,
      'qty': correctedProduct.quantity,
      'last_seen': DateTime.now().toIso8601String(),
      'occurrence': (_learnedPatterns[name]?['occurrence'] ?? 0) + 1,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('learned_patterns', json.encode(_learnedPatterns));
  }

  /// Attempts to improve raw OCR results using previously learned patterns.
  Product applyIntelligence(Product rawDetected) {
    final key = rawDetected.name.toLowerCase();
    if (!_learnedPatterns.containsKey(key)) return rawDetected;

    final pattern = _learnedPatterns[key];
    
    // If we've seen this product before and OCR missed something, fill from memory
    if (rawDetected.size == null || rawDetected.size!.isEmpty) {
       rawDetected.size = pattern['weight'];
    }
    if (rawDetected.quantity == "1") {
       rawDetected.quantity = pattern['qty'] ?? "1";
    }

    return rawDetected;
  }
}
