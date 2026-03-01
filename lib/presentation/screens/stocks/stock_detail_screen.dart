import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sync_ledger/presentation/providers/investment_providers.dart';
import 'package:sync_ledger/domain/services/portfolio_calculator_service.dart';
import 'package:intl/intl.dart';

class StockDetailScreen extends ConsumerWidget {
  final String symbol;

  const StockDetailScreen({
    required this.symbol,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockDetailsAsync = ref.watch(stockDetailsProvider(symbol));

    return Scaffold(
      appBar: AppBar(
        title: Text(symbol),
        elevation: 0,
      ),
      body: stockDetailsAsync.when(
        data: (details) {
          if (details == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.trending_up_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No price data available'),
                  const SizedBox(height: 8),
                  Text(
                    'Please import stock prices from CSE first',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }
          return _buildStockDetail(context, details);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading stock details'),
              const SizedBox(height: 8),
              Text(err.toString(), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockDetail(BuildContext context, StockDetails details) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final percentFormatter = NumberFormat('+0.00;-0.00', 'en_US');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Price Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Price',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'LKR ${formatter.format(details.currentPrice)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Holdings & Value Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Holding',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${details.quantity} shares',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Current Value',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'LKR ${formatter.format(details.currentValue)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Gain/Loss Card
        Card(
          color: details.isPositive
              ? Colors.green.shade50
              : details.isNegative
                  ? Colors.red.shade50
                  : Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gain / Loss',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'LKR ${formatter.format(details.gainLoss)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: details.isPositive
                                ? Colors.green
                                : details.isNegative
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Percentage',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${percentFormatter.format(details.gainLossPercent)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: details.isPositive
                                ? Colors.green
                                : details.isNegative
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Cost Basis Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cost Basis',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LKR ${formatter.format(details.costBasis)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Avg Cost / Share',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LKR ${formatter.format(details.costBasis / (details.quantity > 0 ? details.quantity : 1))}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 30-Day Price Chart
        if (details.priceHistory.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '30-Day Price History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: details.priceHistory
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value.closePrice))
                                .toList(),
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.withOpacity(0.6),
                                Colors.blue.withOpacity(0.3),
                              ],
                            ),
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${details.priceHistory.length} days of data',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Low: LKR ${details.priceHistory.isNotEmpty ? formatter.format(details.priceHistory.map((p) => p.closePrice).reduce((a, b) => a < b ? a : b)) : '0'} | High: LKR ${details.priceHistory.isNotEmpty ? formatter.format(details.priceHistory.map((p) => p.closePrice).reduce((a, b) => a > b ? a : b)) : '0'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: 24),

        // Transaction History
        if (details.transactionHistory.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transaction History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: details.transactionHistory.length,
                itemBuilder: (context, index) {
                  final event = details.transactionHistory[index];
                  final date = DateTime.fromMillisecondsSinceEpoch(event.occurredAtMs);
                  final dateStr = DateFormat('MMM dd, yyyy').format(date);

                  return ListTile(
                    leading: Icon(
                      event.eventType == 'buy' || event.eventType == 'deposit'
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: event.eventType == 'buy' || event.eventType == 'deposit'
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: Text(
                      '${event.eventType.toUpperCase()} ${event.qty} shares',
                    ),
                    subtitle: Text(dateStr),
                    trailing: Text(
                      '${event.qty} qty',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
