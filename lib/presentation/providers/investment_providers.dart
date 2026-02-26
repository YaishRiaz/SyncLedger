import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

final holdingsProvider = FutureProvider<List<Position>>((ref) async {
  final db = ref.watch(databaseProvider);
  final all = await db.getAllPositions();
  // Filter out positions that have been fully sold
  return all.where((p) => p.qty > 0).toList();
});

final familyHoldingsProvider = FutureProvider<List<Position>>((ref) async {
  final db = ref.watch(databaseProvider);
  final all = await db.getAllFamilyPositions();
  return all.where((p) => p.qty > 0).toList();
});

final investmentEventsProvider =
    FutureProvider<List<InvestmentEvent>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllInvestmentEvents();
});
