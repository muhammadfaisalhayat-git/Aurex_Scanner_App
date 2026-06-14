import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';

class TextParser {
  // Agricultural production/inspection keywords
  static const List<String> mfgKeywords = [
    "production", "mfg", "mfd", "manufacture", "prod", "p:", "p .", "mfd date", "mfg date", "date of production", "production date", "packed", "packing date", "mfg. date", "mfd. date", "prod. date", "p. date",
    "انتاج", "تاريخ الانتاج", "تاريخ الإنتاج", "تاريخ الصنع", "تاريخ التصنيع", "تاريخ التعبئة", "تعبئة", "صنع", "DOM", "MFD", "test date", "تاريخ الفحص", "ت الفحص", "ت. فحص", 
    "تاريخ التغليف", "فحص في", "manufactured", "prepared", "creation date", "date of mfg", "P.Date", "ت.انتاج", "ت.صنع", "batch date", "analysis date"
  ];

  // Agricultural expiry/validity keywords
  static const List<String> expKeywords = [
    "expiry", "exp", "ex:", "ex.", "expire", "best before", "e:", "e .", "expiry date", "exp date", "use by", "date of expiry", "date of expiration", "expiration date", "valid until", "valid till", "expier", "validity", "exp. date", "expiry. date", "expiry date", "e. date",
    "انتهاء", "تاريخ الانتهاء", "تاريخ الإنتهاء", "تاريخ النتهاء", "تاريخ انتهاء", "صلاحية", "DOE", "EXP", "يستخدم قبل", "ينتهي في", "صالح حتى", "تاريخ الصلاحية", "مدة الصلاحية", "تاريخ انتهاء الصلاحية",
    "E.Date", "expires", "shelf life", "validity period", "best by", "consume before", "ت.انتهاء", "ت.صلاحية", "صالح لمدة", "يبقى صالحا", "تاريخ الاستهلاك", "حد اقصى", "استخدم قبل"
  ];

  static const List<String> nameKeywords = [
    "product name", "name", "variety", "product", "item", "brand", "crop", "variety name", "trade name",
    "اسم المنتج", "المنتج", "الاسم", "صنف", "صنف :", "المادة", "نوع", "اسم الصنف", "ماركة", "المحصول", "اسم الصنف :", "الاسم التجاري", "اسم النوع", "المحصول :", "الصنف :", "product :"
  ];

  static const List<String> sizeKeywords = [
    "size", "weight", "qty", "quantity", "capacity", "net", "mass", "vol", "w:", "w :", "g.", "net wt", "net weight", "seeds", "content",
    "الحجم", "الوزن", "الكمية", "السعة", "صافي", "الوزن الصافي", "الوزن القائم", "وزن", "الوزن عند التعبئة",
    "الوزن الصافي عند التعبئة", "الكمية الصافية", "الوزن :", "بذور", "بذرة", "حبة", "السعة الصافية", "الوزن الاجمالي", "جرام", "كجم"
  ];

  static const Map<String, String> monthMap = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'may': '05', 'jun': '06',
    'jul': '07', 'aug': '08', 'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
    'يناير': '01', 'فبراير': '02', 'مارس': '03', 'ابريل': '04', 'مايو': '05', 'يونيو': '06',
    'يوليو': '07', 'اغسطس': '08', 'سبتمبر': '09', 'أكتوبر': '10', 'نوفمبر': '11', 'ديسمبر': '12'
  };

  static final List<RegExp> datePatterns = [
    RegExp(r'\b\d{1,2}\s*[./ \-]\s*\d{1,2}\s*[./ \-]\s*\d{4}\b'), // DD/MM/YYYY
    RegExp(r'\b\d{1,2}\s*[./ \-]\s*\d{4}\b'),                      // MM/YYYY
    RegExp(r'\b\d{4}\s*[./ \-]\s*\d{1,2}\b'),                      // YYYY/MM
    RegExp(r'\b\d{8}\b'),                                          // YYYYMMDD
    RegExp(r'\b\d{2}\s*[./ \-]\s*\d{2}\s*[./ \-]\s*\d{2}\b'),      // DD/MM/YY
    RegExp(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[. ]?\s*\d{4}\b', caseSensitive: false),
    RegExp(r'\b\d{1,2}[. ]?\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[. ]?\s*\d{4}\b', caseSensitive: false),
  ];

  static final RegExp unitRegex = RegExp(
    r'(\d+[,.]?\d*)\s*(kg|g|mg|gr|ks|l|ml|liter|litres|gram|kilogram|kgm|غم|غرام|مل|ملي|ك|كيلو|كيلوجرام|كيلو جرام|جرام|جم|كجم|seeds|بذرة|بذور|pcs|piece|gms)',
    caseSensitive: false,
  );

  static Product parse(RecognizedText mlText, {Size? imageSize}) {
    return Product(productCode: "", name: "Scanning...");
  }

  static String normalizeDate(String date) {
    String val = date.toLowerCase();
    for (var month in monthMap.entries) {
      if (val.contains(month.key)) {
        val = val.replaceAll(month.key, month.value);
        val = val.replaceAll('.', '-').replaceAll(' ', '-');
        if (!val.contains('-') && val.length > 2) {
           val = "${val.substring(0,2)}-${val.substring(2)}";
        }
        break;
      }
    }
    // Fixed typo: removed 'binary' from regex
    if (val.length == 8 && !val.contains(RegExp(r'[./ \-]'))) {
       val = "${val.substring(0,2)}/${val.substring(2,4)}/${val.substring(4)}";
    }
    return val;
  }

  static String formatBox(Rect rect, Size? imageSize) {
    if (imageSize == null) return "${rect.left},${rect.top},${rect.right},${rect.bottom}";
    double left = (rect.left / imageSize.width) * 1000.0;
    double top = (rect.top / imageSize.height) * 1000.0;
    double right = (rect.right / imageSize.width) * 1000.0;
    double bottom = (rect.bottom / imageSize.height) * 1000.0;
    return "$left,$top,$right,$bottom";
  }

  static bool isMetadataBlock(String text) {
    final lower = text.toLowerCase();
    final List<String> labels = [
      "date", "tel:", "percent", "tel", "fax", "email", "www.", "mfg", "exp", "batch", "lot", 
      "exported", "imported", "company", "limited", "pvt", "india", "saudi", "variety", "kind", 
      "purity", "germination", "treatment", "crop", "product", "okra", "hybrid", "besf1", "green", "besf", "bes",
      "المحصول", "الصنف", "النوع", "الوزن", "المستورد", "المصدر", "هاتف", "فاكس", "المبيد",
      "americi", "pvt.", "ltd.", "india", "hyderabad", "agriculture"
    ];
    return labels.any((l) => lower.contains(l.toLowerCase()));
  }

  static String? calculateExpiryFromText(String mfgDate, String durationText) {
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

  static bool isValidAgriculturalDate(String date) {
    final parts = date.split(RegExp(r'[./ \-]\s*')).where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return false;
    try {
      int m = int.parse(parts[0]);
      int y = int.parse(parts.last);
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
