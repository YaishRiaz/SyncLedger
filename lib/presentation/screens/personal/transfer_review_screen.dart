import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/core/extensions.dart';
import 'package:sync_ledger/domain/services/transfer_matcher.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

final transferMatchesProvider =
    FutureProvider<List<TransferMatchResult>>((ref) async {
  final db = ref.watch(databaseProvider);
  final matcher = TransferMatcher(db);
  return matcher.findMatches();
});

class TransferReviewScreen extends ConsumerWidget {
  const TransferReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(transferMatchesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Review'),
        actions: [
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final matcher = TransferMatcher(db);
              final count = await matcher.autoMatchAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Auto-matched $count transfers')),
                );
                ref.invalidate(transferMatchesProvider);
              }
            },
            child: const Text('Auto-match All'),
          ),
        ],
      ),
      body: matches.when(
        data: (list) => list.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 64, color: Colors.green,),
                    SizedBox(height: 16),
                    Text('No pending transfer matches'),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) =>
                    _TransferMatchCard(match: list[i]),
              ),
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _TransferMatchCard extends ConsumerWidget {
  const _TransferMatchCard({required this.match});

  final TransferMatchResult match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final outDate = DateTime.fromMillisecondsSinceEpoch(
      match.outTransaction.occurredAtMs,
    );
    final inDate = DateTime.fromMillisecondsSinceEpoch(
      match.inTransaction.occurredAtMs,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Match Score: ${(match.matchScore * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: match.matchScore >= 0.7
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  match.outTransaction.amount.toCurrencyString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _TxnRow(
              label: 'OUT',
              color: Colors.red,
              merchant: match.outTransaction.reference ?? 'Transfer Out',
              date: outDate.toShortDateTime(),
              source: 'NDB',
            ),
            const SizedBox(height: 8),
            const Center(child: Icon(Icons.arrow_downward, size: 20)),
            const SizedBox(height: 8),
            _TxnRow(
              label: 'IN',
              color: Colors.green,
              merchant: match.inTransaction.reference ?? 'Transfer In',
              date: inDate.toShortDateTime(),
              source: 'HNB',
            ),
            if (match.feeTransaction != null) ...[
              const SizedBox(height: 8),
              Text(
                'Fee: LKR ${match.feeTransaction!.amount.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    // Dismiss / skip
                  },
                  child: const Text('Skip'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final db = ref.read(databaseProvider);
                    final matcher = TransferMatcher(db);
                    await matcher.applyMatch(match);
                    ref.invalidate(transferMatchesProvider);
                  },
                  child: const Text('Confirm Match'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({
    required this.label,
    required this.color,
    required this.merchant,
    required this.date,
    required this.source,
  });

  final String label;
  final Color color;
  final String merchant;
  final String date;
  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(merchant, style: theme.textTheme.bodyMedium),
              Text('$date · $source', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
