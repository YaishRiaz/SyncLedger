import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/core/extensions.dart';
import 'package:sync_ledger/presentation/providers/sync_providers.dart';
import 'package:sync_ledger/presentation/providers/transaction_providers.dart';
import 'package:sync_ledger/presentation/providers/investment_providers.dart';
import 'package:sync_ledger/presentation/screens/family/pair_device_screen.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncState = ref.watch(syncStateProvider);
    final familyCashflow = ref.watch(familyCashflowProvider);
    final familyHoldings = ref.watch(familyHoldingsProvider);
    final selectedDays = ref.watch(familySelectedPeriodDaysProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(familyCashflowProvider);
        ref.invalidate(familyHoldingsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sync card ───────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Family Sync', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    syncState.isPaired
                        ? 'Connected to family group'
                        : 'Not paired yet',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!syncState.isPaired) ...[
                        FilledButton.tonal(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PairDeviceScreen(),
                            ),
                          ),
                          child: const Text('Setup Pairing'),
                        ),
                      ] else ...[
                        FilledButton.tonal(
                          onPressed: syncState.isSyncing
                              ? null
                              : () => ref
                                  .read(syncStateProvider.notifier)
                                  .syncNow(),
                          child: Text(
                            syncState.isSyncing ? 'Syncing...' : 'Sync Now',
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (syncState.lastSyncAt != null)
                          Text(
                            'Last: ${syncState.lastSyncAt!.toShortDateTime()}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Period selector ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _kPeriods.map((entry) {
                final selected = entry.$2 == selectedDays;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.$1),
                    selected: selected,
                    onSelected: (_) => ref
                        .read(familySelectedPeriodDaysProvider.notifier)
                        .state = entry.$2,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Family cashflow ──────────────────────────────────────────
          Text('Family Overview', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          familyCashflow.when(
            data: (data) => Column(
              children: [
                _FamilyStatRow(
                  label: 'Combined Income',
                  value: data.income.toCurrencyString(),
                  color: Colors.green,
                ),
                _FamilyStatRow(
                  label: 'Combined Expenses',
                  value: data.expense.toCurrencyString(),
                  color: Colors.red,
                ),
                _FamilyStatRow(
                  label: 'Net Savings',
                  value: (data.income - data.expense).toCurrencyString(),
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),

          // ── Family portfolio ─────────────────────────────────────────
          Text('Family Portfolio', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          familyHoldings.when(
            data: (list) => list.isEmpty
                ? const Text('No combined stock holdings')
                : Column(
                    children: list
                        .map(
                          (h) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(h.symbol),
                            trailing: Text('${h.qty} shares'),
                          ),
                        )
                        .toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

const _kPeriods = [
  ('30D', 30),
  ('3M', 90),
  ('6M', 180),
  ('1Y', 365),
];

class _FamilyStatRow extends StatelessWidget {
  const _FamilyStatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
