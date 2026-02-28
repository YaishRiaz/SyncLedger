import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

final _smsLogProvider = FutureProvider<List<SmsMessage>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllSmsMessages();
});

class SmsLogScreen extends ConsumerWidget {
  const SmsLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final debugMode = ref.watch(debugModeProvider);
    final smsLog = ref.watch(_smsLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_smsLogProvider),
          ),
        ],
      ),
      body: smsLog.when(
        data: (messages) {
          if (messages.isEmpty) {
            return const Center(
              child: Text('No SMS records yet.\nImport SMS from the dashboard.'),
            );
          }

          // Group by parsed status for summary
          final parsed = messages.where((m) => m.parsedStatus == 'parsed').length;
          final skipped = messages.length - parsed;

          return Column(
            children: [
              // Summary banner
              Container(
                width: double.infinity,
                color: colorScheme.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _StatusChip(
                      label: '$parsed parsed',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: '$skipped not parsed',
                      color: Colors.orange,
                    ),
                    const Spacer(),
                    Text(
                      '${messages.length} total',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: messages.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isParsed = msg.parsedStatus == 'parsed';
                    final dt = DateTime.fromMillisecondsSinceEpoch(
                      msg.receivedAtMs,
                    );
                    final dateStr =
                        DateFormat('dd MMM yyyy HH:mm').format(dt);
                    final hasBody =
                        debugMode && msg.bodyEncryptedOrNull != null;

                    return _SmsLogTile(
                      sender: msg.sender,
                      date: dateStr,
                      isParsed: isParsed,
                      body: hasBody ? msg.bodyEncryptedOrNull : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SmsLogTile extends StatefulWidget {
  const _SmsLogTile({
    required this.sender,
    required this.date,
    required this.isParsed,
    this.body,
  });

  final String sender;
  final String date;
  final bool isParsed;
  final String? body;

  @override
  State<_SmsLogTile> createState() => _SmsLogTileState();
}

class _SmsLogTileState extends State<_SmsLogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: widget.body != null ? () => setState(() => _expanded = !_expanded) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sender,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (widget.isParsed ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.isParsed ? 'Parsed' : 'Not parsed',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isParsed ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.body != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            if (_expanded && widget.body != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.body!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
