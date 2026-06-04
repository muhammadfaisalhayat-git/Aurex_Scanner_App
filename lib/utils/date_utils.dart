import 'package:intl/intl.dart';

class AppDateUtils {
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    
    final cleanStr = dateStr.trim().replaceAll(' ', '');
    // Comprehensive formats including single-digit months
    final formats = [
      'dd/MM/yyyy', 'd/M/yyyy', 'MM/yyyy', 'M/yyyy',
      'dd-MM-yyyy', 'd-M-yyyy', 'MM-yyyy', 'M-yyyy',
      'dd.MM.yyyy', 'd.M.yyyy', 'MM.yyyy', 'M.yyyy',
      'yyyy/MM/dd', 'yyyy-MM-dd', 'MM/dd/yyyy'
    ];

    for (var format in formats) {
      try {
        final date = DateFormat(format).parse(cleanStr);
        // If it's a month-only format, set to the last day of the month
        if (format.contains('M/yyyy') || format.contains('M-yyyy') || format.contains('M.yyyy') || 
            format.contains('MM/yyyy') || format.contains('MM-yyyy') || format.contains('MM.yyyy')) {
          return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
        }
        return date;
      } catch (_) {}
    }
    return null;
  }

  static int calculateRemainingDays(String? expDateStr) {
    final expDate = parseDate(expDateStr);
    if (expDate == null) return 0;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Ensure we count the full difference including the end date
    return expDate.difference(today).inDays;
  }

  static bool isExpired(String? expDateStr) {
    final expDate = parseDate(expDateStr);
    if (expDate == null) return false;
    final now = DateTime.now();
    return expDate.isBefore(DateTime(now.year, now.month, now.day));
  }
}
