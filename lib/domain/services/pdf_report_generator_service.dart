import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/core/logger.dart';
import 'package:intl/intl.dart';

class PdfReportGeneratorService {
  final AppDatabase db;

  PdfReportGeneratorService({required this.db});

  /// Generate income/expense report for a custom date range
  Future<Uint8List> generateIncomeExpenseReport({
    required DateTime startDate,
    required DateTime endDate,
    required String profileId,
  }) async {
    try {
      AppLogger.d('PdfReportGenerator: Generating income/expense report');

      // Fetch transactions for the date range
      final transactions = await db.getTransactionsByDateRange(
        profileId,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      );

      // Create PDF
      final pdf = pw.Document();

      // Add title page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SyncLedger Finance Report',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Income & Expense Statement',
                  style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 32),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Report Period',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        'Generated on ${DateFormat('MMM dd, yyyy - HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Add summary page
      pdf.addPage(
        _buildSummaryPage(transactions, startDate, endDate),
      );

      // Add transactions table
      if (transactions.isNotEmpty) {
        pdf.addPage(
          _buildTransactionsPage(transactions),
        );
      }

      // Add category breakdown
      pdf.addPage(
        _buildCategoryBreakdownPage(transactions),
      );

      AppLogger.d('PdfReportGenerator: Report generated successfully');
      return pdf.save();
    } catch (e) {
      AppLogger.e('PdfReportGenerator: Error generating report: $e');
      rethrow;
    }
  }

  /// Build summary statistics page
  pw.Page _buildSummaryPage(
    List<Transaction> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Calculate metrics
    double totalIncome = 0;
    double totalExpense = 0;
    double totalTransfers = 0;

    for (final txn in transactions) {
      if (txn.direction == 'income') {
        totalIncome += txn.amount;
      } else if (txn.direction == 'expense') {
        totalExpense += txn.amount;
      } else if (txn.type == 'transfer') {
        totalTransfers += txn.amount;
      }
    }

    final netSavings = totalIncome - totalExpense;
    final avgTransaction = transactions.isNotEmpty
        ? (totalIncome + totalExpense) / transactions.length
        : 0.0;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Summary Statistics',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Total Income', 'LKR ${_formatNumber(totalIncome)}', PdfColors.green),
                _buildStatCard('Total Expenses', 'LKR ${_formatNumber(totalExpense)}', PdfColors.red),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Net Savings', 'LKR ${_formatNumber(netSavings)}',
                    netSavings > 0 ? PdfColors.green : PdfColors.red),
                _buildStatCard('Avg Transaction', 'LKR ${_formatNumber(avgTransaction)}', PdfColors.blueGrey),
              ],
            ),
            pw.SizedBox(height: 32),
            pw.Text(
              'Transaction Breakdown',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildBreakdownRow('Total Transactions:', '${transactions.length}'),
                  _buildBreakdownRow('Income Transactions:',
                      '${transactions.where((t) => t.direction == 'income').length}'),
                  _buildBreakdownRow('Expense Transactions:',
                      '${transactions.where((t) => t.direction == 'expense').length}'),
                  _buildBreakdownRow('Transfers:',
                      '${transactions.where((t) => t.type == 'transfer').length}'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build transactions detail page
  pw.Page _buildTransactionsPage(List<Transaction> transactions) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(3),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Date', isHeader: true),
                    _buildTableCell('Type', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                    _buildTableCell('Description', isHeader: true),
                    _buildTableCell('Category', isHeader: true),
                  ],
                ),
                // Data rows
                ...transactions.take(50).map((txn) {
                  final date = DateTime.fromMillisecondsSinceEpoch(txn.occurredAtMs);
                  return pw.TableRow(
                    children: [
                      _buildTableCell(DateFormat('MMM dd').format(date)),
                      _buildTableCell(txn.type ?? 'N/A'),
                      _buildTableCell(
                        'LKR ${_formatNumber(txn.amount)}',
                        align: pw.TextAlign.right,
                      ),
                      _buildTableCell(txn.merchant ?? txn.reference ?? '-'),
                      _buildTableCell(txn.category ?? '-'),
                    ],
                  );
                }).toList(),
              ],
            ),
            if (transactions.length > 50)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 12),
                child: pw.Text(
                  'Showing first 50 transactions. Total: ${transactions.length}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build category breakdown page
  pw.Page _buildCategoryBreakdownPage(List<Transaction> transactions) {
    // Calculate category sums
    final categoryMap = <String, double>{};
    for (final txn in transactions) {
      if (txn.direction == 'expense') {
        final category = txn.category ?? 'Uncategorized';
        categoryMap[category] = (categoryMap[category] ?? 0) + txn.amount;
      }
    }

    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpense = categoryMap.values.fold<double>(0, (a, b) => a + b);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Category Breakdown',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Category', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                    _buildTableCell('% of Total', isHeader: true),
                  ],
                ),
                ...sortedCategories.map((entry) {
                  final percentage = totalExpense > 0
                      ? (entry.value / totalExpense * 100).toStringAsFixed(1)
                      : '0.0';
                  return pw.TableRow(
                    children: [
                      _buildTableCell(entry.key),
                      _buildTableCell(
                        'LKR ${_formatNumber(entry.value)}',
                        align: pw.TextAlign.right,
                      ),
                      _buildTableCell(
                        '$percentage%',
                        align: pw.TextAlign.right,
                      ),
                    ],
                  );
                }).toList(),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell(
                      'TOTAL',
                      isHeader: true,
                    ),
                    _buildTableCell(
                      'LKR ${_formatNumber(totalExpense)}',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                    _buildTableCell(
                      '100.0%',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Helper: Build stat card
  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 200,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper: Build breakdown row
  pw.Widget _buildBreakdownRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              )),
        ],
      ),
    );
  }

  /// Helper: Build table cell
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Helper: Format number with commas
  String _formatNumber(double value) {
    return NumberFormat('#,##0.00', 'en_US').format(value);
  }
}
