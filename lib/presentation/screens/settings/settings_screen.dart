import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_ledger/core/constants.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';
import 'package:sync_ledger/presentation/providers/export_provider.dart';
import 'package:sync_ledger/presentation/providers/investment_providers.dart';
import 'package:sync_ledger/presentation/providers/sms_providers.dart';
import 'package:sync_ledger/presentation/providers/transaction_providers.dart';
import 'package:sync_ledger/presentation/providers/sync_providers.dart';
import 'package:sync_ledger/domain/services/biometric_service.dart';
import 'package:sync_ledger/presentation/screens/settings/sms_log_screen.dart';
import 'package:sync_ledger/presentation/screens/family/pair_device_screen.dart';

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
              return Column(
                children: [
                  // Import SMS with period picker
                  ListTile(
                    leading: Icon(
                      smsState.isImporting
                          ? Icons.hourglass_bottom_outlined
                          : Icons.sms_outlined,
                    ),
                    title: const Text('Import SMS'),
                    subtitle: Text(smsState.statusText),
                    trailing: smsState.isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: smsState.isImporting
                        ? null
                        : () => _showImportPeriodDialog(context, ref),
                  ),
                  SwitchListTile(
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
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('View SMS Log'),
            subtitle: const Text('See all processed messages and parse status'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SmsLogScreen(),
              ),
            ),
          ),
          const Divider(),

          // ── Profiles ─────────────────────────────────────────────────────
          const _SectionHeader(title: 'Profiles'),
          _ProfilesSection(),
          const Divider(),

          // ── Family Sync ──────────────────────────────────────────────────
          Consumer(
            builder: (context, ref, _) {
              final familySyncEnabledAsync =
                  ref.watch(familySyncEnabledProvider);
              return familySyncEnabledAsync.when(
                data: (isEnabled) {
                  return Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Family Sync'),
                        subtitle: Text(
                          isEnabled
                              ? 'Sync transactions across family devices'
                              : 'Disabled - tap to enable',
                        ),
                        value: isEnabled,
                        onChanged: (value) async {
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool(
                              PrefKeys.familySyncEnabled, value);
                          ref.invalidate(familySyncEnabledProvider);
                        },
                      ),
                      if (isEnabled) ...[
                        const _SectionHeader(title: 'Family Sync Settings'),
                        _FamilySyncSection(),
                      ],
                      const Divider(),
                    ],
                  );
                },
                loading: () => const SwitchListTile(
                  title: Text('Family Sync'),
                  subtitle: Text('Loading...'),
                  value: false,
                  onChanged: null,
                ),
                error: (_, __) => const SwitchListTile(
                  title: Text('Family Sync'),
                  subtitle: Text('Error loading setting'),
                  value: false,
                  onChanged: null,
                ),
              );
            },
          ),

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

// ─── Family Sync Section ─────────────────────────────────────────────────────

class _FamilySyncSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverUrlAsync = ref.watch(serverUrlProvider);

    return serverUrlAsync.when(
      data: (serverUrl) {
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Server URL'),
              subtitle: Text(serverUrl),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showServerUrlDialog(context, ref, serverUrl),
            ),
            ListTile(
              leading: const Icon(Icons.phonelink_setup_outlined),
              title: const Text('Pair New Device'),
              subtitle: const Text('Create or join a family group via QR code'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateToPairDevice(context),
            ),
          ],
        );
      },
      loading: () => const Column(
        children: [
          ListTile(
            leading: Icon(Icons.cloud_sync_outlined),
            title: Text('Server URL'),
            subtitle: Text('Loading...'),
          ),
          ListTile(
            leading: Icon(Icons.phonelink_setup_outlined),
            title: Text('Pair New Device'),
            subtitle: Text('Loading...'),
          ),
        ],
      ),
      error: (_, __) => const Column(
        children: [
          ListTile(
            leading: Icon(Icons.cloud_sync_outlined),
            title: Text('Server URL'),
            subtitle: Text('Error loading'),
          ),
          ListTile(
            leading: Icon(Icons.phonelink_setup_outlined),
            title: Text('Pair New Device'),
            subtitle: Text('Error loading'),
          ),
        ],
      ),
    );
  }

  void _showServerUrlDialog(
    BuildContext context,
    WidgetRef ref,
    String currentUrl,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ServerUrlDialog(currentUrl: currentUrl),
    );
  }

  void _navigateToPairDevice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PairDeviceScreen(),
      ),
    );
  }
}

class _ServerUrlDialog extends ConsumerStatefulWidget {
  const _ServerUrlDialog({required this.currentUrl});

  final String currentUrl;

  @override
  ConsumerState<_ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends ConsumerState<_ServerUrlDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() async {
    final newUrl = _controller.text.trim();
    if (newUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a server URL')),
        );
      }
      return;
    }

    try {
      await ref
          .read(serverUrlNotifierProvider.notifier)
          .updateServerUrl(newUrl);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server URL updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server URL'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'e.g., 192.168.1.100',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
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
    ref.invalidate(familyCashflowProvider);
    ref.invalidate(familyHoldingsProvider);
    ref.invalidate(filteredTransactionsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared.')),
      );
    }
  }
}

// ─── Import Period Dialog ─────────────────────────────────────────────────────

// days=0 means "all time"; null means dismissed (no selection made).
Future<void> _showImportPeriodDialog(BuildContext context, WidgetRef ref) async {
  const options = [
    ('Last 30 days', 30),
    ('Last 60 days', 60),
    ('Last 6 months', 182),
    ('Last 1 year', 365),
    ('All time', 0),
  ];

  final days = await showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Import SMS from…'),
      children: options.map((opt) {
        return SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop(opt.$2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(opt.$1),
          ),
        );
      }).toList(),
    ),
  );

  if (days == null || !context.mounted) return; // dismissed

  final sinceMs = days == 0
      ? null
      : DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

  await ref.read(smsImportStateProvider.notifier).importSms(sinceMs: sinceMs);
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
