import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/presentation/providers/transaction_providers.dart';
import 'package:sync_ledger/presentation/providers/sms_providers.dart';
import 'package:sync_ledger/core/extensions.dart';

class PersonalDashboard extends ConsumerWidget {
  const PersonalDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = ref.watch(monthlyCashflowProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthlyCashflowProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SmsImportCard(),
          const SizedBox(height: 16),
          stats.when(
            data: (data) => Column(
              children: [
                _StatCard(
                  title: 'Income This Month',
                  value: data.income.toCurrencyString(),
                  icon: Icons.arrow_downward,
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _StatCard(
                  title: 'Expenses This Month',
                  value: data.expense.toCurrencyString(),
                  icon: Icons.arrow_upward,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                _StatCard(
                  title: 'Net Cashflow',
                  value: (data.income - data.expense).toCurrencyString(),
                  icon: Icons.account_balance_wallet,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _StatCard(
                  title: 'Transfers',
                  value: data.transfers.toCurrencyString(),
                  icon: Icons.swap_horiz,
                  color: colorScheme.tertiary,
                ),
              ],
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _SmsImportCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smsState = ref.watch(smsImportStateProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SMS Import', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              smsState.statusText,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: smsState.isImporting
                      ? null
                      : () => ref
                          .read(smsImportStateProvider.notifier)
                          .importSms(),
                  child: Text(
                    smsState.isImporting ? 'Importing...' : 'Import SMS',
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: smsState.isListening
                      ? () => ref
                          .read(smsImportStateProvider.notifier)
                          .stopListening()
                      : () => ref
                          .read(smsImportStateProvider.notifier)
                          .startListening(),
                  child: Text(
                    smsState.isListening ? 'Stop Listener' : 'Start Listener',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
