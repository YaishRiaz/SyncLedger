import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sync_ledger/core/extensions.dart';
import 'package:sync_ledger/presentation/providers/analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedPeriod = ref.watch(analyticsSelectedPeriodProvider);
    final monthlyData = ref.watch(monthlyAnalyticsProvider);
    final topMerchants = ref.watch(topMerchantsProvider);
    final categoryBreakdown = ref.watch(categoryBreakdownProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthlyAnalyticsProvider);
        ref.invalidate(topMerchantsProvider);
        ref.invalidate(categoryBreakdownProvider);
      },
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Period selector ────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AnalyticsPeriod.values.map((period) {
              final selected = period == selectedPeriod;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(period.label),
                  selected: selected,
                  onSelected: (_) => ref
                      .read(analyticsSelectedPeriodProvider.notifier)
                      .state = period,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // ── Cashflow bar chart ─────────────────────────────────────────────
        Text('Cashflow', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        monthlyData.when(
          data: (data) {
            if (data.isEmpty) {
              return const SizedBox(
                height: 160,
                child: Center(child: Text('No data for this period')),
              );
            }
            final sortedKeys = data.keys.toList()..sort();
            final totalIncome =
                data.values.fold(0.0, (s, v) => s + v.income);
            final totalExpense =
                data.values.fold(0.0, (s, v) => s + v.expense);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      barGroups: sortedKeys.asMap().entries.map((e) {
                        final stats = data[e.value]!;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: stats.income,
                              color: Colors.green,
                              width: 8,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            BarChartRodData(
                              toY: stats.expense,
                              color: Colors.red,
                              width: 8,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                        );
                      }).toList(),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final label =
                                rodIndex == 0 ? 'Income' : 'Expense';
                            return BarTooltipItem(
                              '$label\n${rod.toY.toCurrencyString()}',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LegendDot(
                      color: Colors.green,
                      label: 'Income ${totalIncome.toCurrencyString()}',
                    ),
                    const SizedBox(width: 16),
                    _LegendDot(
                      color: Colors.red,
                      label: 'Expense ${totalExpense.toCurrencyString()}',
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
        const SizedBox(height: 28),

        // ── Category Breakdown ─────────────────────────────────────────────
        Text('Category Breakdown', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        categoryBreakdown.when(
          data: (cats) {
            if (cats.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No expense data for this period'),
                ),
              );
            }
            final total = cats.values.fold(0.0, (s, v) => s + v);
            final colors = [
              colorScheme.primary,
              colorScheme.secondary,
              colorScheme.tertiary,
              Colors.orange,
              Colors.purple,
              Colors.teal,
              Colors.pink,
              Colors.indigo,
              Colors.amber,
              Colors.cyan,
            ];

            return Column(
              children: [
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: cats.entries.toList().asMap().entries.map((e) {
                        final idx = e.key;
                        final cat = e.value;
                        final pct = total > 0 ? cat.value / total * 100 : 0;
                        return PieChartSectionData(
                          value: cat.value,
                          title: pct >= 8
                              ? '${pct.toStringAsFixed(0)}%'
                              : '',
                          color: colors[idx % colors.length],
                          radius: 65,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Category legend with amounts and percentages
                ...cats.entries.toList().asMap().entries.map((e) {
                  final idx = e.key;
                  final cat = e.value;
                  final pct = total > 0 ? cat.value / total * 100 : 0;
                  final color = colors[idx % colors.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cat.key,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          cat.value.toCurrencyString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
        const SizedBox(height: 28),

        // ── Top Merchants ──────────────────────────────────────────────────
        Text('Top Merchants', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        topMerchants.when(
          data: (merchants) {
            if (merchants.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No merchant data for this period')),
              );
            }
            final total = merchants.values.fold(0.0, (s, v) => s + v);
            return Column(
              children: merchants.entries.take(10).map((e) {
                final pct = total > 0 ? e.value / total * 100 : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.key,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: total > 0 ? e.value / total : 0,
                                minHeight: 4,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            e.value.toCurrencyString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
        const SizedBox(height: 16),
      ],
    ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
