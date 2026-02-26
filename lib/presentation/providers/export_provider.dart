import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

/// Converts a value to a safe CSV cell, quoting if it contains
/// commas, quotes, or newlines.
String _csvCell(dynamic value) {
  final s = value?.toString() ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Converts a list-of-rows into a CSV string.
String _toCsv(List<List<dynamic>> rows) {
  return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
}

class ExportService {
  ExportService(this._ref);
  final Ref _ref;

  Future<void> exportTransactionsCsv() async {
    final db = _ref.read(databaseProvider);
    final txns = await db.getAllTransactions();

    final rows = <List<dynamic>>[
      [
        'Date',
        'Direction',
        'Amount',
        'Currency',
        'Type',
        'Category',
        'Merchant',
        'Reference',
      ],
      ...txns.map((t) => [
            DateTime.fromMillisecondsSinceEpoch(t.occurredAtMs)
                .toIso8601String(),
            t.direction,
            t.amount,
            t.currency,
            t.type,
            t.category ?? '',
            t.merchant ?? '',
            t.reference ?? '',
          ],),
    ];

    final csv = _toCsv(rows);
    await _shareFile('sync_ledger_transactions.csv', csv);
  }

  Future<void> exportStocksCsv() async {
    final db = _ref.read(databaseProvider);
    final events = await db.getAllInvestmentEvents();

    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Symbol', 'Quantity'],
      ...events.map((e) => [
            DateTime.fromMillisecondsSinceEpoch(e.occurredAtMs)
                .toIso8601String(),
            e.eventType,
            e.symbol,
            e.qty,
          ],),
    ];

    final csv = _toCsv(rows);
    await _shareFile('sync_ledger_stocks.csv', csv);
  }

  Future<void> _shareFile(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)]);
  }
}

final exportProvider = Provider<ExportService>((ref) {
  return ExportService(ref);
});