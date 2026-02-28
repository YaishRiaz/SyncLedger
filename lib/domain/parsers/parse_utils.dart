import 'package:intl/intl.dart';

abstract final class ParseUtils {
  static double parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Parse amount from text with flexible formats:
  /// "LKR 5,000.00", "Rs 5000", "Rs. 5000/-", "Amount: 5000 LKR"
  static double parseAmountFlexible(String text) {
    // Try to find amount patterns
    final patterns = [
      RegExp(r'(?:LKR|Rs\.?)\s*([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false),
      RegExp(r'([0-9,]+(?:\.[0-9]{2})?)\s*(?:LKR|Rs)', caseSensitive: false),
      RegExp(r'Amount[:\s]+([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amount = match.group(1) ?? '';
        final cleaned = amount.replaceAll(',', '').trim();
        final parsed = double.tryParse(cleaned);
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }
    return 0.0;
  }

  static String? extractLast4(String? account) {
    if (account == null || account.isEmpty) return null;
    final digits = account.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return null;
    return digits.substring(digits.length - 4);
  }

  /// Extract last 4 digits from various account formats
  static String? extractLast4Flexible(String text) {
    // Look for account numbers in various formats
    final patterns = [
      RegExp(r'(?:AC|Account)[\s:]*(?:No\.?)?[\s]*(?:X+)?([0-9]{4})', caseSensitive: false),
      RegExp(r'([0-9]{4})(?:\s|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Extract balance from text
  static double? extractBalance(String text) {
    final patterns = [
      RegExp(r'[Bb]al(?:ance)?[:\s]+(?:LKR|Rs\.?)\s*([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false),
      RegExp(r'[Aa]vailable[:\s]+(?:LKR|Rs\.?)\s*([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amount = match.group(1) ?? '';
        final cleaned = amount.replaceAll(',', '').trim();
        final parsed = double.tryParse(cleaned);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  /// Parse multiple date formats
  static DateTime? parseMultipleDateFormats(String dateStr) {
    if (dateStr.isEmpty) return null;

    // Try formats in order
    final formats = [
      'dd/MM/yy', // 22/02/26
      'dd-MM-yy', // 22-02-26
      'd MMM yyyy', // 22 Feb 2026
      'd MMM yy', // 22 Feb 26
      'dd-MMM-yy', // 22-FEB-26
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(dateStr.trim());
      } catch (_) {
        // Try next format
      }
    }

    return null;
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
