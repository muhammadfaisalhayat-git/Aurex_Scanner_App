import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';

class TextParser {
  static const List<String> _mfgKeywords = [
    "production", "mfg", "mfd", "manufacture", "prod", "p:", "p .", "mfd date", "mfg date", "date of production", "production date", "packed", "packing date",
    "انتاج", "تاريخ الانتاج", "تاريخ الإنتاج", "تاريخ الصنع", "تاريخ التصنيع", "صنع", "DOM", "MFD", "test date", "تاريخ الفحص", "ت الفحص", "ت. فحص"
  ];

  static const List<String> _expKeywords = [
    "expiry", "exp", "ex:", "ex.", "expire", "best before", "e:", "e .", "expiry date", "exp date", "use by", "date of expiry", "date of expiration", "expiration date", "valid until", "valid till", "expier",
    "انتهاء", "تاريخ الانتهاء", "تاريخ الإنتهاء", "تاريخ النتهاء", "DOE", "EXP", "يستخدم قبل", "ينتهي في", "صالح حتى", "تاريخ الصلاحية", "صلاحية"
  ];

  static const List<String> _nameKeywords = [
    "product name", "name", "variety", "product", "item", "brand", "crop",
    "اسم المنتج", "المنتج", "الاسم", "صنف", "صنف :", "المادة", "نوع", "اسم الصنف", "ماركة", "المحصول"
  ];

  static const List<String> _sizeKeywords = [
    "size", "weight", "qty", "quantity", "capacity", "net", "mass", "vol", "w:", "w :", "g.", "net wt", "net weight", "seeds",
    "الحجم", "الوزن", "الكمية", "السعة", "صافي", "الوزن الصافي", "الوزن القائم", "وزن", "الوزن عند التعبئة",
    "الوزن الصافي عند التعبئة", "الكمية الصافية", "الوزن :", "بذور", "بذرة", "حبة"
  ];

  static final List<RegExp> _datePatterns = [
    RegExp(r'\b\d{1,2}\s*[./ \-]\s*\d{1,2}\s*[./ \-]\s*\d{4}\b'),
    RegExp(r'\b\d{1,2}\s*[./ \-]\s*\d{4}\b'),
    RegExp(r'\b\d{4}\s*[./ \-]\s*\d{1,2}\b'),
    RegExp(r'\b\d{8}\b'),
  ];

  static final RegExp _unitRegex = RegExp(
    r'(\d+[,.]?\d*)\s*(kg|g|mg|gr|ks|l|ml|liter|litres|gram|kilogram|kgm|غم|غرام|مل|ملي|ك|كيلو|كيلوجرام|كيلو جرام|جرام|جم|كجم|seeds|بذرة|بذور|pcs|piece|gms)',
    caseSensitive: false,
  );

  static Product parse(RecognizedText mlText) {
    List<_DateElement> dateElements = [];
    String foundQuantity = "1";
    String? foundSize;
    String foundProductCode = "";
    String? foundMfg;
    String? foundExp;
    String? mfgBox;
    String? expBox;

    // 1. Name Detection - PRIORITY: Largest Boldest text block at the top
    final blocks = mlText.blocks.toList();
    blocks.sort((a, b) => b.boundingBox.height.compareTo(a.boundingBox.height));
    
    String smartName = "Unknown Product";
    for (var block in blocks) {
      final text = block.text.toLowerCase();
      // Heuristic: Identify product titles (Large text, limited technical symbols)
      if (block.boundingBox.height > 18 && 
          !text.contains("date") && 
          !text.contains("tel:") && 
          !text.contains("/") && 
          !text.contains("percent") &&
          !text.contains("lot") &&
          !text.contains("s000")) {
        smartName = block.text.split('\n').first.trim();
        break;
      }
    }

    // 2. Process all lines for metadata
    for (var block in mlText.blocks) {
      final bText = block.text.toLowerCase();
      
      // Extraction of Weight/Size/Qty
      for (var key in _sizeKeywords) {
        if (bText.contains(key.toLowerCase())) {
          final int idx = bText.indexOf(key.toLowerCase());
          final afterKey = block.text.substring(idx + key.length).trim();
          final match = _unitRegex.firstMatch(afterKey);
          if (match != null) {
            final unit = match.group(2)!.toLowerCase();
            if (["kg", "g", "mg", "gr", "gms", "liter", "gram", "كجم", "غرام"].contains(unit)) {
              foundSize ??= match.group(0);
            } else {
              foundQuantity = match.group(1)!;
            }
          }
        }
      }

      // Date parsing with enhanced patterns
      for (var line in block.lines) {
        final lineText = line.text;
        for (var pattern in _datePatterns) {
          for (var match in pattern.allMatches(lineText)) {
            String val = match.group(0)!;
            if (val.length == 8 && !val.contains(RegExp(r'[./ \-]'))) {
               val = "${val.substring(0,2)}/${val.substring(2,4)}/${val.substring(4)}";
            }
            if (_isValidAgriculturalDate(val)) {
              dateElements.add(_DateElement(val, line));
            }
          }
        }
      }
    }

    // 3. Proximity-based Date Mapping
    for (var dateElem in dateElements) {
      double minDist = 9999;
      int bestType = 0; // 1: MFG, 2: EXP

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
      if (bestType == 1 && foundMfg == null) {
        foundMfg = dateElem.value;
        mfgBox = "${dateElem.line.boundingBox.left},${dateElem.line.boundingBox.top},${dateElem.line.boundingBox.right},${dateElem.line.boundingBox.bottom}";
      }
      if (bestType == 2 && foundExp == null) {
        foundExp = dateElem.value;
        expBox = "${dateElem.line.boundingBox.left},${dateElem.line.boundingBox.top},${dateElem.line.boundingBox.right},${dateElem.line.boundingBox.bottom}";
      }
    }

    return Product(
      productCode: foundProductCode,
      name: smartName,
      mfgDate: foundMfg,
      expDate: foundExp,
      quantity: foundQuantity,
      size: foundSize,
      mfgBox: mfgBox,
      expBox: expBox,
    );
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
