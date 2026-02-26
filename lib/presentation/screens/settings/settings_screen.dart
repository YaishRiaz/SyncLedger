import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';
import 'package:sync_ledger/presentation/providers/export_provider.dart';
import 'package:sync_ledger/presentation/providers/sms_providers.dart';
import 'package:sync_ledger/domain/services/biometric_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final debugMode = ref.watch(debugModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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
