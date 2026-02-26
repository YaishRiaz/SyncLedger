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
    final monthlyData = ref.watch(monthlyAnalyticsProvider);
    final topMerchants = ref.watch(topMerchantsProvider);
    final categoryBreakdown = ref.watch(categoryBreakdownProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Monthly Cashflow', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        monthlyData.when(
          data: (data) => SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: data.entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.income,
                        color: Colors.green,
                        width: 8,
                      ),
                      BarChartRodData(
                        toY: e.value.expense,
                        color: Colors.red,
                        width: 8,
                      ),
                    ],
                  );
                }).toList(),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
              ),
            ),
          ),
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
        const SizedBox(height: 24),
        Text('Category Breakdown', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        categoryBreakdown.when(
          data: (cats) => SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: cats.entries.map((e) {
                  final colors = [
                    colorScheme.primary,
                    colorScheme.secondary,
                    colorScheme.tertiary,
                    Colors.orange,
                    Colors.purple,
                    Colors.teal,
                    Colors.pink,
                    Colors.indigo,
                  ];
                  final idx = cats.keys.toList().indexOf(e.key);
                  return PieChartSectionData(
                    value: e.value,
                    title: e.key,
                    color: colors[idx % colors.length],
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
        const SizedBox(height: 24),
        Text('Top Merchants', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        topMerchants.when(
          data: (merchants) => Column(
            children: merchants.entries
                .take(10)
                .map(
                  (e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.key),
                    trailing: Text(
                      e.value.toCurrencyString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}
