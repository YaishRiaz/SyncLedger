import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';
import 'package:sync_ledger/presentation/providers/export_provider.dart';
import 'package:sync_ledger/presentation/providers/investment_providers.dart';
import 'package:sync_ledger/presentation/providers/sms_providers.dart';
import 'package:sync_ledger/presentation/providers/transaction_providers.dart';
import 'package:sync_ledger/domain/services/biometric_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugMode = ref.watch(debugModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Privacy ──────────────────────────────────────────────────────
          const _SectionHeader(title: 'Privacy'),
          SwitchListTile(
            title: const Text('Debug Mode'),
            subtitle: const Text(
              'Store raw SMS body for troubleshooting. '
              'Disable to keep only parsed data.',
            ),
            value: debugMode,
            onChanged: (v) =>
                ref.read(debugModeProvider.notifier).state = v,
          ),
          FutureBuilder<bool>(
            future: BiometricService.canCheckBiometrics(),
            builder: (context, snapshot) {
              final canUseBiometrics = snapshot.data ?? false;
              final appLockEnabled = ref.watch(appLockEnabledProvider);

              return appLockEnabled.when(
                data: (enabled) => SwitchListTile(
                  title: const Text('App Lock'),
                  subtitle: Text(
                    canUseBiometrics
                        ? 'Require fingerprint/face to open'
                        : 'Biometrics not available on this device',
                  ),
                  value: enabled,
                  onChanged: canUseBiometrics
                      ? (v) async {
                          await BiometricService.setEnabled(v);
                          ref.invalidate(appLockEnabledProvider);
                        }
                      : null,
                ),
                loading: () => const SwitchListTile(
                  title: Text('App Lock'),
                  subtitle: Text('Loading...'),
                  value: false,
                  onChanged: null,
                ),
                error: (_, __) => const SwitchListTile(
                  title: Text('App Lock'),
                  subtitle: Text('Error loading'),
                  value: false,
                  onChanged: null,
                ),
              );
            },
          ),
          const Divider(),

          // ── SMS Listener ─────────────────────────────────────────────────
          const _SectionHeader(title: 'SMS Listener'),
          Consumer(
            builder: (context, ref, _) {
              final smsState = ref.watch(smsImportStateProvider);
              return SwitchListTile(
                title: const Text('Auto-Start Listener'),
                subtitle: Text(
                  smsState.isListening
                      ? 'Currently listening for new SMS'
                      : 'Listener is stopped',
                ),
                value: smsState.isListening,
                onChanged: (v) async {
                  if (v) {
                    await ref
                        .read(smsImportStateProvider.notifier)
                        .startListening();
                  } else {
                    await ref
                        .read(smsImportStateProvider.notifier)
                        .stopListening();
                  }
                },
              );
            },
          ),
          const Divider(),

          // ── Profiles ─────────────────────────────────────────────────────
          const _SectionHeader(title: 'Profiles'),
          _ProfilesSection(),
          const Divider(),

          // ── Data ─────────────────────────────────────────────────────────
          const _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Transactions (CSV)'),
            onTap: () => ref.read(exportProvider).exportTransactionsCsv(),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Stock Activity (CSV)'),
            onTap: () => ref.read(exportProvider).exportStocksCsv(),
          ),
          const Divider(),

          // ── Danger Zone ───────────────────────────────────────────────────
          const _SectionHeader(title: 'Danger Zone'),
          _ClearDataTile(),
          const Divider(),

          // ── About ─────────────────────────────────────────────────────────
          const _SectionHeader(title: 'About'),
          const ListTile(
            title: Text('SyncLedger'),
            subtitle: Text('v1.0.0 · Privacy-first finance tracker'),
          ),
        ],
      ),
    );
  }
}

// ─── Profiles Section ────────────────────────────────────────────────────────

class _ProfilesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profileListProvider);
    final activeIdAsync = ref.watch(activeProfileIdProvider);

    return activeIdAsync.when(
      data: (activeId) {
        final active = profiles.where((p) => p.id == activeId).firstOrNull;
        return ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(active?.name ?? 'My Account'),
          subtitle: const Text('Tap to switch or manage profiles'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showProfileSheet(context, ref, profiles, activeId),
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.person_outline),
        title: Text('Loading profile...'),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showProfileSheet(
    BuildContext context,
    WidgetRef ref,
    List<ProfileEntry> profiles,
    String activeId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProfileBottomSheet(
        profiles: profiles,
        activeId: activeId,
      ),
    );
  }
}

class _ProfileBottomSheet extends ConsumerStatefulWidget {
  const _ProfileBottomSheet({
    required this.profiles,
    required this.activeId,
  });

  final List<ProfileEntry> profiles;
  final String activeId;

  @override
  ConsumerState<_ProfileBottomSheet> createState() =>
      _ProfileBottomSheetState();
}

class _ProfileBottomSheetState extends ConsumerState<_ProfileBottomSheet> {
  final _nameController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profiles = ref.watch(profileListProvider);
    final activeIdAsync = ref.watch(activeProfileIdProvider);
    final activeId =
        activeIdAsync.valueOrNull ?? widget.activeId;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Profiles', style: theme.textTheme.titleMedium),
            ),
            ...profiles.map((profile) => RadioListTile<String>(
                  value: profile.id,
                  groupValue: activeId,
                  title: Text(profile.name),
                  secondary: profiles.length > 1
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            await ref
                                .read(profileListProvider.notifier)
                                .deleteProfile(profile.id);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        )
                      : null,
                  onChanged: (_) async {
                    await ref
                        .read(profileListProvider.notifier)
                        .switchProfile(profile.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                )),
            const Divider(),
            if (_adding)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Profile name',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _saveNewProfile(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saveNewProfile,
                      child: const Text('Add'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => setState(() => _adding = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              )
            else
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add Profile'),
                onTap: () => setState(() => _adding = true),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNewProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await ref.read(profileListProvider.notifier).addProfile(name);
    _nameController.clear();
    setState(() => _adding = false);
  }
}

// ─── Clear All Data ───────────────────────────────────────────────────────────

class _ClearDataTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.delete_forever, color: colorScheme.error),
      title: Text(
        'Clear All Data',
        style: TextStyle(color: colorScheme.error),
      ),
      subtitle: const Text(
          'Permanently removes all transactions, SMS records, and holdings'),
      onTap: () => _confirmClear(context, ref),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all transactions, SMS records, '
          'investment events, and account balances. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await db.deleteAllData();

    // Refresh all data-dependent providers
    ref.invalidate(accountsProvider);
    ref.invalidate(smsImportStateProvider);
    ref.invalidate(holdingsProvider);
    ref.invalidate(investmentEventsProvider);
    ref.invalidate(monthlyCashflowProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared.')),
      );
    }
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
