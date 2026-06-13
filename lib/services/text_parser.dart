import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';

class TextParser {
  // Over 60 combined production/inspection keywords
  static const List<String> _mfgKeywords = [
    "production", "mfg", "mfd", "manufacture", "prod", "p:", "p .", "mfd date", "mfg date", "date of production", "production date", "packed", "packing date",
    "انتاج", "تاريخ الانتاج", "تاريخ الإنتاج", "تاريخ الصنع", "تاريخ التصنيع", "تاريخ التعبئة", "تعبئة", "صنع", "DOM", "MFD", "test date", "تاريخ الفحص", "ت الفحص", "ت. فحص", 
    "تاريخ التغليف", "فحص في", "manufactured", "prepared", "creation date", "date of mfg", "P.Date", "ت.انتاج", "ت.صنع", "batch date", "analysis date"
  ];

  // Over 60 combined expiry/validity keywords
  static const List<String> _expKeywords = [
    "expiry", "exp", "ex:", "ex.", "expire", "best before", "e:", "e .", "expiry date", "exp date", "use by", "date of expiry", "date of expiration", "expiration date", "valid until", "valid till", "expier", "validity",
    "انتهاء", "تاريخ الانتهاء", "تاريخ الإنتهاء", "تاريخ النتهاء", "تاريخ انتهاء", "صلاحية", "DOE", "EXP", "يستخدم قبل", "ينتهي في", "صالح حتى", "تاريخ الصلاحية", "مدة الصلاحية", "تاريخ انتهاء الصلاحية",
    "E.Date", "expires", "shelf life", "validity period", "best by", "consume before", "ت.انتهاء", "ت.صلاحية", "صالح لمدة", "يبقى صالحا", "تاريخ الاستهلاك", "حد اقصى", "استخدم قبل"
  ];

  static const List<String> _nameKeywords = [
    "product name", "name", "variety", "product", "item", "brand", "crop", "variety name", "trade name",
    "اسم المنتج", "المنتج", "الاسم", "صنف", "صنف :", "المادة", "نوع", "اسم الصنف", "ماركة", "المحصول", "اسم الصنف :", "الاسم التجاري", "اسم النوع", "المحصول :", "الصنف :"
  ];

  static const List<String> _sizeKeywords = [
    "size", "weight", "qty", "quantity", "capacity", "net", "mass", "vol", "w:", "w :", "g.", "net wt", "net weight", "seeds", "content",
    "الحجم", "الوزن", "الكمية", "السعة", "صافي", "الوزن الصافي", "الوزن القائم", "وزن", "الوزن عند التعبئة",
    "الوزن الصافي عند التعبئة", "الكمية الصافية", "الوزن :", "بذور", "بذرة", "حبة", "السعة الصافية", "الوزن الاجمالي", "جرام", "كجم"
  ];

  // Expanded patterns to catch partial or poorly recognized dates
  static final List<RegExp> _datePatterns = [
    RegExp(r'\b\d{1,2}\s*[./ \-]\s*\d{1,2}\s*[./ \-]\s*\d{4}\b'), // DD/MM/YYYY or MM/DD/YYYY
    RegExp(r'\b\d{1,2}\s*[./ \-]\s*\d{4}\b'),                      // MM/YYYY
    RegExp(r'\b\d{4}\s*[./ \-]\s*\d{1,2}\b'),                      // YYYY/MM
    RegExp(r'\b\d{8}\b'),                                          // YYYYMMDD or DDMMYYYY
    RegExp(r'\b\d{2}\s*[./ \-]\s*\d{2}\s*[./ \-]\s*\d{2}\b'),      // DD/MM/YY
  ];

  static final RegExp _unitRegex = RegExp(
    r'(\d+[,.]?\d*)\s*(kg|g|mg|gr|ks|l|ml|liter|litres|gram|kilogram|kgm|غم|غرام|مل|ملي|ك|كيلو|كيلوجرام|كيلو جرام|جرام|جم|كجم|seeds|بذرة|بذور|pcs|piece|gms)',
    caseSensitive: false,
  );

  static Product parse(RecognizedText mlText, {Size? imageSize}) {
    List<_DateElement> dateElements = [];
    String foundQuantity = "1";
    String? foundSize;
    String foundProductCode = "";
    String? foundMfg;
    String? foundExp;
    String? mfgBox;
    String? expBox;
    String? smartName;

    // 1. Keyword-Based Field Extraction (Priority 1)
    for (var block in mlText.blocks) {
      final String fullText = block.text;
      final String lowerText = fullText.toLowerCase();

      // Name Detection
      if (smartName == null) {
        for (var key in _nameKeywords) {
          if (lowerText.contains(key.toLowerCase())) {
            final int idx = lowerText.indexOf(key.toLowerCase());
            String val = fullText.substring(idx + key.length).trim();
            val = val.replaceAll(RegExp(r'^[:\s-]+'), '').split('\n').first.trim();
            if (val.isNotEmpty && val.length > 2) {
              smartName = val;
              break;
            }
          }
        }
      }

      // Weight/Size Detection
      for (var key in _sizeKeywords) {
        if (lowerText.contains(key.toLowerCase())) {
          final int idx = lowerText.indexOf(key.toLowerCase());
          final afterKey = fullText.substring(idx + key.length).trim();
          final match = _unitRegex.firstMatch(afterKey);
          if (match != null) {
            final unit = match.group(2)!.toLowerCase();
            if (["kg", "g", "mg", "gr", "gms", "liter", "gram"].contains(unit)) {
              foundSize ??= match.group(0);
            } else {
              foundQuantity = match.group(1)!;
            }
          }
        }
      }

      // Capture all dates
      for (var line in block.lines) {
        for (var pattern in _datePatterns) {
          for (var match in pattern.allMatches(line.text)) {
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

    // 2. Advanced Proximity Mapping (Supports RTL layouts)
    for (var dateElem in dateElements) {
      double minDist = 9999;
      int bestType = 0; // 1: MFG, 2: EXP

      for (var block in mlText.blocks) {
        final bText = block.text.toLowerCase();
        final bBox = block.boundingBox;
        final dBox = dateElem.line.boundingBox;

        // Calculate distances
        final dy = (bBox.top + bBox.height / 2) - (dBox.top + dBox.height / 2);
        
        // In Arabic labels, the label is often to the RIGHT of the value.
        // Label.left - Value.right should be small and positive.
        // Or if they are on the same line, dy is small.
        final dxRTL = bBox.left - dBox.right; // Label is on the right
        final dxLTR = dBox.left - bBox.right; // Label is on the left
        
        double dx = (dxRTL.abs() < dxLTR.abs()) ? dxRTL.abs() : dxLTR.abs();
        
        // Proximity score: heavy weight on Y-alignment, then X-distance
        final dist = dy.abs() * 5.0 + dx * 1.0;

        if (dist < minDist) {
          if (_mfgKeywords.any((k) => bText.contains(k.toLowerCase()))) {
            bestType = 1; minDist = dist;
          } else if (_expKeywords.any((k) => bText.contains(k.toLowerCase()))) {
            bestType = 2; minDist = dist;
          }
        }
      }
      
      if (bestType == 1 && (foundMfg == null || minDist < 50)) {
        foundMfg = dateElem.value;
        mfgBox = _formatBox(dateElem.line.boundingBox, imageSize);
      } else if (bestType == 2 && (foundExp == null || minDist < 50)) {
        foundExp = dateElem.value;
        expBox = _formatBox(dateElem.line.boundingBox, imageSize);
      }
    }

    // 3. Duration-based calculation (backup)
    if (foundExp == null && foundMfg != null) {
      for (var block in mlText.blocks) {
        final text = block.text;
        if (text.contains("صلاحية") || text.contains("الصلاحية") || text.contains("validity") || text.contains("shelf life")) {
           final calculated = _calculateExpiryFromText(foundMfg, text);
           if (calculated != null) {
             foundExp = calculated;
             break;
           }
        }
      }
    }

    // 4. Fallback Name Detection
    if (smartName == null || smartName == "Unknown Product") {
      final sortedBlocks = mlText.blocks.toList();
      sortedBlocks.sort((a, b) => b.boundingBox.height.compareTo(a.boundingBox.height));
      for (var block in sortedBlocks) {
        final text = block.text.toLowerCase();
        if (block.boundingBox.height > 18 && !_isMetadataBlock(text)) {
          smartName = block.text.split('\n').first.trim();
          break;
        }
      }
    }

    return Product(
      productCode: foundProductCode,
      name: smartName ?? "Unknown Product",
      mfgDate: foundMfg,
      expDate: foundExp,
      quantity: foundQuantity,
      size: foundSize,
      mfgBox: mfgBox,
      expBox: expBox,
    );
  }

  static String _formatBox(Rect rect, Size? imageSize) {
    if (imageSize == null) return "${rect.left},${rect.top},${rect.right},${rect.bottom}";
    double left = (rect.left / imageSize.width) * 1000.0;
    double top = (rect.top / imageSize.height) * 1000.0;
    double right = (rect.right / imageSize.width) * 1000.0;
    double bottom = (rect.bottom / imageSize.height) * 1000.0;
    return "$left,$top,$right,$bottom";
  }

  static bool _isMetadataBlock(String text) {
    return text.contains("date") || text.contains("tel:") || text.contains("/") || 
           text.contains("percent") || text.contains("tel") || text.contains("fax") ||
           text.contains("email") || text.contains("www.");
  }

  static String? _calculateExpiryFromText(String mfgDate, String durationText) {
    int yearsToAdd = 0;
    final text = durationText.toLowerCase();
    if (text.contains("عامان") || text.contains("سنتان") || text.contains("2 عام") || text.contains("2 سنة") || text.contains("two years")) {
      yearsToAdd = 2;
    } else if (text.contains("ثلاث سنوات") || text.contains("3 سنوات") || text.contains("3 عام") || text.contains("three years")) {
      yearsToAdd = 3;
    } else if (text.contains("عام") || text.contains("سنة") || text.contains("1 عام") || text.contains("1 سنة") || text.contains("one year")) {
      yearsToAdd = 1;
    }
    if (yearsToAdd == 0) return null;
    try {
      final parts = mfgDate.split(RegExp(r'[./ \-]\s*')).where((s) => s.isNotEmpty).toList();
      if (parts.length < 2) return null;
      int m = int.parse(parts[0]);
      int y = int.parse(parts.last);
      if (y < 100) y += 2000;
      int expY = y + yearsToAdd;
      return "${m.toString().padLeft(2, '0')}-$expY";
    } catch (_) { return null; }
  }

  static bool _isValidAgriculturalDate(String date) {
    final parts = date.split(RegExp(r'[./ \-]\s*')).where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return false;
    try {
      int m = int.parse(parts[0]);
      int y = int.parse(parts.last);
      // Agricultural products can have long shelf lives, 2010-2050 is safe
      return (m >= 1 && m <= 12) && ((y >= 10 && y <= 50) || (y >= 2010 && y <= 2050));
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
