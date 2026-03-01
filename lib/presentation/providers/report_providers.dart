import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/services/pdf_report_generator_service.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

/// Date range for report generation
class DateRange {
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  DateRange({
    required this.startDate,
    required this.endDate,
    required this.label,
  });
}

/// Notifier for managing selected report date range
class ReportDateRangeNotifier extends StateNotifier<DateRange> {
  ReportDateRangeNotifier()
      : super(
          DateRange(
            startDate: _getLastMonthStart(),
            endDate: DateTime.now(),
            label: 'Last Month',
          ),
        );

  /// Set custom date range
  void setCustomRange(DateTime start, DateTime end) {
    state = DateRange(
      startDate: start,
      endDate: end,
      label:
          'Custom (${start.month}/${start.day} - ${end.month}/${end.day})',
    );
  }

  /// Set to last month
  void setLastMonth() {
    final now = DateTime.now();
    final firstDayThisMonth = DateTime(now.year, now.month, 1);
    final lastDayLastMonth = DateTime(now.year, now.month, 0);
    final firstDayLastMonth =
        DateTime(lastDayLastMonth.year, lastDayLastMonth.month, 1);

    state = DateRange(
      startDate: firstDayLastMonth,
      endDate: lastDayLastMonth,
      label: 'Last Month',
    );
  }

  /// Set to last 30 days
  void setLast30Days() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    state = DateRange(
      startDate: thirtyDaysAgo,
      endDate: now,
      label: 'Last 30 Days',
    );
  }

  /// Set to current year
  void setThisYear() {
    final now = DateTime.now();
    final firstDayYear = DateTime(now.year, 1, 1);

    state = DateRange(
      startDate: firstDayYear,
      endDate: now,
      label: 'This Year',
    );
  }

  /// Set to last year (full 12 months)
  void setLastYear() {
    final now = DateTime.now();
    final firstDayLastYear = DateTime(now.year - 1, 1, 1);
    final lastDayLastYear = DateTime(now.year - 1, 12, 31);

    state = DateRange(
      startDate: firstDayLastYear,
      endDate: lastDayLastYear,
      label: 'Last Year',
    );
  }

  /// Set to specific month
  void setMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    state = DateRange(
      startDate: firstDay,
      endDate: lastDay,
      label: '${_monthName(month)} $year',
    );
  }

  static DateTime _getLastMonthStart() {
    final now = DateTime.now();
    final firstDayThisMonth = DateTime(now.year, now.month, 1);
    return firstDayThisMonth.subtract(const Duration(days: 1));
  }

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

/// Current selected report date range
final reportDateRangeProvider =
    StateNotifierProvider<ReportDateRangeNotifier, DateRange>((ref) {
  return ReportDateRangeNotifier();
});

/// PDF Report Generator Service
final pdfReportGeneratorProvider =
    Provider<PdfReportGeneratorService>((ref) {
  final db = ref.watch(databaseProvider);
  return PdfReportGeneratorService(db: db);
});

/// Transactions for the selected date range (for preview in UI)
final reportTransactionsProvider =
    FutureProvider<List<Transaction>>((ref) async {
  final db = ref.watch(databaseProvider);
  final dateRange = ref.watch(reportDateRangeProvider);
  final activeId = await ref.watch(activeProfileIdProvider.future);

  return db.getTransactionsByDateRange(
    activeId,
    dateRange.startDate.millisecondsSinceEpoch,
    dateRange.endDate.millisecondsSinceEpoch,
  );
});
