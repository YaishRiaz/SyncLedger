import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/core/extensions.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';
import 'package:sync_ledger/presentation/providers/transaction_providers.dart';
import 'package:sync_ledger/presentation/providers/sms_providers.dart';

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
        ref.invalidate(accountsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SmsImportCard(),
          const SizedBox(height: 16),
          _BankBalanceCard(),
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

class _BankBalanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accountsAsync = ref.watch(accountsProvider);
    final selectedBank = ref.watch(selectedBankProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) return const SizedBox.shrink();

        // Derive unique institution names
        final institutions = accounts
            .map((a) => a.institution)
            .toSet()
            .toList()
          ..sort();

        // Compute displayed balance
        final filtered = selectedBank == null
            ? accounts
            : accounts.where((a) => a.institution == selectedBank).toList();

        final totalBalance = filtered.fold<double>(
          0,
          (sum, a) => sum + (a.balance ?? 0),
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Available Balance',
                        style: theme.textTheme.titleMedium),
                    DropdownButton<String?>(
                      value: selectedBank,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Banks'),
                        ),
                        ...institutions.map((inst) => DropdownMenuItem(
                              value: inst,
                              child: Text(inst),
                            )),
                      ],
                      onChanged: (val) =>
                          ref.read(selectedBankProvider.notifier).state = val,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  totalBalance.toCurrencyString(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                // Show per-account breakdown when "All Banks" is selected and there are multiple accounts
                if (selectedBank == null && accounts.length > 1) ...[
                  const SizedBox(height: 8),
                  ...accounts.map((a) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${a.institution} ···${a.last4 ?? ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              (a.balance ?? 0).toCurrencyString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
