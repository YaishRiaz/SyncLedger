import 'package:intl/intl.dart';

abstract final class ParseUtils {
  static double parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  static String? extractLast4(String? account) {
    if (account == null || account.isEmpty) return null;
    final digits = account.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return null;
    return digits.substring(digits.length - 4);
  }

  /// Parse HNB date format: "22/02/26" + "20:23:11"
  static DateTime? parseDateTimeSL(String date, String time) {
    try {
      final parts = date.split('/');
      if (parts.length != 3) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      var year = int.parse(parts[2]);
      if (year < 100) year += 2000;

      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;

      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  /// Parse NDB date format: "22 Feb 2026" + "20:23"
  static DateTime? parseDateTimeNdb(String date, String time) {
    try {
      final dt = DateFormat('d MMM yyyy').parse(date);
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      return DateTime(dt.year, dt.month, dt.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  /// Parse CDS date format: "11-FEB-26"
  static DateTime? parseCdsDate(String day, String month, String year) {
    try {
      final monthMap = {
        'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
        'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
        'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
      };
      final d = int.parse(day);
      final m = monthMap[month.toUpperCase()] ?? 1;
      var y = int.parse(year);
      if (y < 100) y += 2000;
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }
}
