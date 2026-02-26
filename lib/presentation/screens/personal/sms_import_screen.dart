import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/presentation/providers/sms_providers.dart';

class SmsImportScreen extends ConsumerWidget {
  const SmsImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smsImportStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SMS Import')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              state.isImporting
                  ? Icons.hourglass_top
                  : Icons.sms_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              state.statusText,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (state.isImporting)
              const LinearProgressIndicator()
            else ...[
              _ResultRow(
                label: 'Messages processed',
                value: '${state.importedCount}',
              ),
              _ResultRow(
                label: 'Successfully parsed',
                value: '${state.parsedCount}',
              ),
              _ResultRow(
                label: 'Needs review',
                value: '${state.importedCount - state.parsedCount}',
              ),
            ],
            const Spacer(),
            if (!state.isImporting)
              FilledButton.icon(
                onPressed: () => ref
                    .read(smsImportStateProvider.notifier)
                    .importSms(),
                icon: const Icon(Icons.refresh),
                label: const Text('Import Again'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

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
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
