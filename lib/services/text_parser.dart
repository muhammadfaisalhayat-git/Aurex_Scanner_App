import '../models/product.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextParser {
  static final List<String> mfgKeywords = [
    "production", "mfg", "mfd", "manufacture", "prod", "p:", "p :", "p.", "test date", "packed", "packing date", "pkd",
    "انتاج", "تاريخ الانتاج", "تاريخ الإنتاج", "تعبئة", "فحص", "تاريخ الفحص"
  ];

  static final List<String> expKeywords = [
    "expiry", "exp", "expire", "best before", "e:", "e :", "e.", "use by", "valid until", "valid till", "exp. date", "exp date",
    "انتهاء", "تاريخ الانتهاء", "تاريخ الإنتهاء", "صالح حتى", "تاريخ الصلاحية", "صلاحية"
  ];

  static final List<String> sizeKeywords = [
    "size", "weight", "qty", "quantity", "net", "w:", "g.", "net weight", "seeds",
    "الحجم", "الوزن", "الكمية", "صافي", "بذور", "بذرة"
  ];

  static final massUnits = ["kg", "g", "mg", "l", "ml", "gram", "kilogram", "غم", "غرام", "جم", "كجم"];
  static final countUnits = ["seeds", "بذرة", "بذور", "pcs", "piece", "حبة"];

  static final unitRegex = RegExp(
    r'(\d+[,.]?\d*)\s*(kg|g|mg|l|ml|gram|kilogram|غم|غرام|جم|كجم|seeds|بذرة|بذور|pcs|piece|حبة)',
    caseSensitive: false,
  );

  static Product parse(RecognizedText recognizedText) {
    String foundQuantity = "1";
    String? foundSize;
    String? foundMfg;
    String? foundExp;

    final fullText = recognizedText.text;
    final List<_DateElement> dateElements = [];

    // 1. Prioritize text following keywords for Size/Quantity
    for (TextBlock block in recognizedText.blocks) {
      final blockText = block.text.toLowerCase();
      for (var key in sizeKeywords) {
        if (blockText.contains(key.toLowerCase())) {
          final afterKey = blockText.substring(blockText.indexOf(key.toLowerCase()) + key.length);
          final match = unitRegex.firstMatch(afterKey);
          if (match != null) {
            final value = match.group(0)!;
            final unit = match.group(2)!.toLowerCase();
            if (massUnits.contains(unit)) {
              foundSize = value;
            } else if (countUnits.contains(unit)) {
              foundQuantity = match.group(1)!;
            }
          }
        }
      }

      // Extract Dates from each line for spatial context
      for (TextLine line in block.lines) {
        final dateRegex = RegExp(r'\b\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\b');
        for (var match in dateRegex.allMatches(line.text)) {
          dateElements.add(_DateElement(match.group(0)!, line));
        }
      }
    }

    // 2. Fallback to generic pattern search for missing units
    if (foundSize == null || foundQuantity == "1") {
      for (var match in unitRegex.allMatches(fullText)) {
        final value = match.group(0)!;
        final unit = match.group(2)!.toLowerCase();
        if (foundSize == null && massUnits.contains(unit)) {
          foundSize = value;
        } else if (foundQuantity == "1" && countUnits.contains(unit)) {
          foundQuantity = match.group(1)!;
        }
      }
    }

    // 3. Smart Date Attribution based on proximity to keywords
    for (var dateElem in dateElements) {
      final dateRect = dateElem.line.boundingBox;
      double minMfgDist = 9999;
      double minExpDist = 9999;

      for (TextBlock block in recognizedText.blocks) {
        final blockText = block.text.toLowerCase();
        final blockRect = block.boundingBox;

        // Calculate a simple distance (vertical distance prioritized)
        final dy = (blockRect.top + blockRect.height / 2) - (dateRect.top + dateRect.height / 2);
        final dx = (blockRect.left) - (dateRect.left);
        final dist = dy.abs() * 2.0 + dx.abs() * 0.5;

        if (mfgKeywords.any((k) => blockText.contains(k.toLowerCase()))) {
          if (dist < minMfgDist) minMfgDist = dist;
        }
        if (expKeywords.any((k) => blockText.contains(k.toLowerCase()))) {
          if (dist < minExpDist) minExpDist = dist;
        }
      }

      if (minMfgDist < minExpDist && minMfgDist < 200) {
        if (foundMfg == null) foundMfg = dateElem.value;
      } else if (minExpDist < minMfgDist && minExpDist < 200) {
        if (foundExp == null) foundExp = dateElem.value;
      }
    }

    // 4. Default Date Logic if context attribution failed
    if (foundMfg == null && foundExp == null && dateElements.isNotEmpty) {
      if (dateElements.length >= 2) {
        foundMfg = dateElements[0].value;
        foundExp = dateElements[1].value;
      } else {
        foundExp = dateElements[0].value;
      }
    }

    return Product(
      productCode: "",
      name: _extractSmartName(recognizedText),
      mfgDate: foundMfg,
      expDate: foundExp,
      quantity: foundQuantity,
      size: foundSize,
    );
  }

  static String _extractSmartName(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return "Unknown Product";

    // Filter out technical blocks and return the most likely name
    final noise = RegExp(r'(?i)batch|lot|weight|net|tel|phone|price|exp|mfg|prod|date|expiry|بذور|seeds|انتاج|فحص|تاريخ');

    for (var block in recognizedText.blocks) {
      final text = block.text.split('\n').first.trim();
      if (text.length > 3 && !noise.hasMatch(text)) {
        return text;
      }
    }

    return recognizedText.blocks.first.text.split('\n').first;
  }
}

class _DateElement {
  final String value;
  final TextLine line;
  _DateElement(this.value, this.line);
}
