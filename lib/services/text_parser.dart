import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';

class TextParser {
  static const List<String> _mfgKeywords = [
    "production", "mfg", "mfd", "manufacture", "prod", "p:", "p .", "mfd date", "mfg date", "date of production", "production date", "packed", "packing date",
    "انتاج", "تاريخ الانتاج", "تاريخ الإنتاج", "تاريخ الصنع", "تاريخ التصنيع", "صنع", "DOM", "MFD"
  ];

  static const List<String> _expKeywords = [
    "expiry", "exp", "ex:", "ex.", "expire", "best before", "e:", "e .", "expiry date", "exp date", "use by", "date of expiry", "date of expiration", "expiration date", "valid until", "valid till", "expier",
    "انتهاء", "تاريخ الانتهاء", "تاريخ الإنتهاء", "تاريخ النتهاء", "DOE", "EXP", "يستخدم قبل", "ينتهي في", "صالح حتى"
  ];

  static const List<String> _nameKeywords = ["crop name", "product name", "name", "variety", "product", "item", "brand", "crop", "اسم الصنف", "اسم المنتج"];
  
  static const List<String> _excludeKeywords = ["tsw", "weight", "percent", "germination", "purity", "reg.", "no.", "lot", "tel", "gram", "origin", "cultivated"];

  // Stricter date patterns to avoid decimals like 91.26
  static final List<RegExp> _datePatterns = [
    RegExp(r'\b\d{1,2}/\d{1,2}/\d{4}\b'), // 12/12/2024
    RegExp(r'\b\d{1,2}-\d{1,2}-\d{4}\b'), // 12-12-2024
    RegExp(r'\b\d{1,2}/\d{4}\b'),         // 12/2024
    RegExp(r'\b\d{1,2}-\d{4}\b'),         // 12-2024
  ];

  static Product parse(RecognizedText mlText) {
    List<_DateElement> dateElements = [];
    String foundQuantity = "1";
    String? foundSize;
    String foundProductCode = "";
    String? foundMfg;
    String? foundExp;

    final blocks = mlText.blocks.toList();
    blocks.sort((a, b) => b.boundingBox.height.compareTo(a.boundingBox.height));
    
    String smartName = "Unknown Product";
    for (var block in blocks) {
      final text = block.text.toLowerCase();
      if (block.boundingBox.height > 18 && !_shouldExclude(text) && !text.contains("/")) {
        smartName = block.text.split('\n').first.trim();
        break;
      }
    }

    for (var block in mlText.blocks) {
      final bText = block.text.toLowerCase();
      
      // Extraction of Weight/Size
      if (foundSize == null) {
        final weightRegex = RegExp(r'(\d+[,.]?\d*)\s*(gr|g|kg|ml|l|gms|gram)', caseSensitive: false);
        final match = weightRegex.firstMatch(block.text);
        if (match != null) foundSize = match.group(0);
      }

      // Date parsing
      for (var line in block.lines) {
        final lineText = line.text;
        for (var pattern in _datePatterns) {
          for (var match in pattern.allMatches(lineText)) {
            String val = match.group(0)!;
            if (_isValidAgriculturalDate(val)) {
              dateElements.add(_DateElement(val, line));
            }
          }
        }
      }
    }

    // Proximity-based Date Mapping
    for (var dateElem in dateElements) {
      double minDist = 9999;
      int bestType = 0;

      for (var block in mlText.blocks) {
        final bText = block.text.toLowerCase();
        final bBox = block.boundingBox;
        final dBox = dateElem.line.boundingBox;

        final dy = (bBox.top + bBox.height / 2) - (dBox.top + dBox.height / 2);
        final dx = bBox.left - dBox.left;
        final dist = dy.abs() * 3.0 + dx.abs() * 0.1;

        if (dist < minDist) {
          if (_mfgKeywords.any((k) => bText.contains(k.toLowerCase()))) {
            bestType = 1; minDist = dist;
          } else if (_expKeywords.any((k) => bText.contains(k.toLowerCase()))) {
            bestType = 2; minDist = dist;
          }
        }
      }
      if (bestType == 1 && foundMfg == null) foundMfg = dateElem.value;
      if (bestType == 2 && foundExp == null) foundExp = dateElem.value;
    }

    return Product(
      productCode: foundProductCode,
      name: smartName,
      mfgDate: foundMfg,
      expDate: foundExp,
      quantity: foundQuantity,
      size: foundSize,
    );
  }

  static bool _shouldExclude(String text) {
    return _excludeKeywords.any((k) => text.contains(k));
  }

  static bool _isValidAgriculturalDate(String date) {
    final parts = date.split(RegExp(r'[./ \-]')).where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return false;
    try {
      int m = int.parse(parts[0]);
      int y = int.parse(parts.last);
      return (m >= 1 && m <= 12) && ((y >= 20 && y <= 40) || (y >= 2020 && y <= 2040));
    } catch (_) { return false; }
  }

  static String cleanProductCode(String code) {
    return code.replaceAll(RegExp(r'\][A-Z]\d|^\[C1|^\(01\)'), '').trim();
  }
}

class _DateElement {
  final String value;
  final TextLine line;
  _DateElement(this.value, this.line);
}
