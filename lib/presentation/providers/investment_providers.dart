import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

final holdingsProvider = FutureProvider<List<Position>>((ref) async {
  final db = ref.watch(databaseProvider);
  // Filter by active profile so other profiles' holdings don't bleed in
  final activeId = await ref.watch(activeProfileIdProvider.future);
  return db.getPositionsForProfile(activeId);
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
