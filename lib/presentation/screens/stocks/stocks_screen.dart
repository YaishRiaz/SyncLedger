import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sync_ledger/presentation/providers/investment_providers.dart';
import 'package:sync_ledger/domain/models/enums.dart';

class StocksScreen extends ConsumerWidget {
  const StocksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsProvider);
    final events = ref.watch(investmentEventsProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Holdings'),
              Tab(text: 'Activity'),
            ],
            labelColor: theme.colorScheme.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Holdings tab
                holdings.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(holdingsProvider);
                          ref.invalidate(investmentEventsProvider);
                        },
                        child: const SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: 300,
                            child: Center(child: Text('No current holdings')),
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(holdingsProvider);
                        ref.invalidate(investmentEventsProvider);
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final h = list[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                h.symbol.length >= 3
                                    ? h.symbol.substring(0, 3)
                                    : h.symbol,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              h.symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Text(
                              '${h.qty} shares',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
                // Activity tab
                events.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(holdingsProvider);
                          ref.invalidate(investmentEventsProvider);
                        },
                        child: const SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: 300,
                            child: Center(child: Text('No stock activity yet')),
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(holdingsProvider);
                        ref.invalidate(investmentEventsProvider);
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final ev = list[i];
                          final isBuy = ev.eventType == 'buy' ||
                              ev.eventType == 'deposit';
                          final date = DateTime.fromMillisecondsSinceEpoch(
                            ev.occurredAtMs,
                          );
                          return ListTile(
                            leading: Icon(
                              isBuy
                                  ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline,
                              color: isBuy ? Colors.green : Colors.red,
                              size: 28,
                            ),
                            title: Text(
                              '${ev.eventType.toUpperCase()} ${ev.symbol}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                DateFormat('dd MMM yyyy').format(date),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isBuy
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${ev.qty}',
                                style: TextStyle(
                                  color: isBuy ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
