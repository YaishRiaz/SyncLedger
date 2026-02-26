import 'package:intl/intl.dart';

extension StringX on String {
  String get normalized => replaceAll(RegExp(r'\s+'), ' ').trim();

  String? get nullIfEmpty => isEmpty ? null : this;
}

extension DoubleX on double {
  String toCurrencyString({String symbol = 'LKR'}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
      locale: 'en_US',
    );
    return formatter.format(this);
  }
}

extension DateTimeX on DateTime {
  String toShortDate() => DateFormat('dd MMM yyyy').format(this);

  String toShortDateTime() => DateFormat('dd MMM yyyy HH:mm').format(this);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

extension IntX on int {
  DateTime get fromMillis => DateTime.fromMillisecondsSinceEpoch(this);
}
