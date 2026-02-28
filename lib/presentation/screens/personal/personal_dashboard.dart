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
    final smsState = ref.watch(smsImportStateProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthlyCashflowProvider);
        ref.invalidate(accountsProvider);
      },
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
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
          // Compact listener status bar at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SmsStatusBar(smsState: smsState),
          ),
        ],
      ),
    );
  }
}

/// Slim status strip shown at the bottom of the dashboard.
class _SmsStatusBar extends StatelessWidget {
  const _SmsStatusBar({required this.smsState});
  final SmsImportState smsState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color dotColor;
    String label;
    if (smsState.isImporting) {
      dotColor = Colors.orange;
      label = smsState.statusText;
    } else if (smsState.isListening) {
      dotColor = Colors.green;
      label = 'Listening for SMS';
    } else {
      dotColor = colorScheme.onSurfaceVariant;
      label = smsState.statusText;
    }

    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (smsState.isImporting)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
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
    final profileAccountsAsync = ref.watch(profileAccountsProvider);
    final activeProfileAsync = ref.watch(activeProfileIdProvider);
    final profileListAsync = ref.watch(profileListProvider);
    final selectedBank = ref.watch(selectedBankProvider);

    return activeProfileAsync.when(
      data: (activeProfileId) {
        // Find active profile name
        final profiles = ref.watch(profileListProvider);
        final activeProfile = profiles.where((p) => p.id == activeProfileId).firstOrNull;
        final profileName = activeProfile?.name ?? 'My Account';

        return profileAccountsAsync.when(
          data: (profileAccounts) {
            if (profileAccounts.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Balance ($profileName)',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Text(
                        '0.00',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No accounts assigned to this profile. Go to Settings > Account Management to assign accounts.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final institutions = profileAccounts
                .map((a) => a.institution)
                .toSet()
                .toList()
              ..sort();

            final filtered = selectedBank == null
                ? profileAccounts
                : profileAccounts.where((a) => a.institution == selectedBank).toList();

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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Available Balance',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '$profileName · ${profileAccounts.length} account${profileAccounts.length != 1 ? 's' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (institutions.isNotEmpty)
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
                    if (selectedBank == null && profileAccounts.length > 1) ...[
                      const SizedBox(height: 8),
                      ...profileAccounts.map((a) => Padding(
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
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
              backgroundColor: color.withValues(alpha: 0.15),
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
