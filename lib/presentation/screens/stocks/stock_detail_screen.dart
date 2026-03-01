import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sync_ledger/domain/models/price_prediction.dart';
import 'package:sync_ledger/domain/services/cse_scraper_service.dart';
import 'package:sync_ledger/domain/services/portfolio_calculator_service.dart';
import 'package:sync_ledger/presentation/providers/investment_providers.dart';

class StockDetailScreen extends ConsumerWidget {
  final String symbol;

  const StockDetailScreen({required this.symbol, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockDetailsAsync = ref.watch(stockDetailsProvider(symbol));
    final stockInfoAsync = ref.watch(stockInfoProvider(symbol));
    final predictionsAsync = ref.watch(stockPredictionProvider(symbol));

    final logoPath = stockInfoAsync.valueOrNull?.logoPath;
    final suffix = stockInfoAsync.valueOrNull?.symbolSuffix;
    final displayTicker = suffix != null ? '$symbol.$suffix' : symbol;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAppBarLogo(context, logoPath),
            const SizedBox(width: 10),
            Text(displayTicker),
          ],
        ),
        elevation: 0,
      ),
      body: stockDetailsAsync.when(
        data: (details) {
          if (details == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.trending_up_outlined,
                      size: 48, color: Colors.grey),
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
          final predictions = predictionsAsync.valueOrNull ?? [];
          return _buildStockDetail(context, details, predictions);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading stock details'),
              const SizedBox(height: 8),
              Text(err.toString(),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarLogo(BuildContext context, String? logoPath) {
    final fallback = CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        symbol.length >= 2 ? symbol.substring(0, 2) : symbol,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
    if (logoPath == null) return fallback;
    return ClipOval(
      child: Image.network(
        'https://www.cse.lk/$logoPath',
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _buildStockDetail(
    BuildContext context,
    StockDetails details,
    List<PricePrediction> predictions,
  ) {
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final pctFmt = NumberFormat('+0.00;-0.00', 'en_US');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Current Price ──────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Price',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 8),
                Text(
                  'LKR ${fmt.format(details.currentPrice)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Holdings & Value ────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Holding',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text('${details.quantity} shares',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Current Value',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text('LKR ${fmt.format(details.currentValue)}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Gain / Loss ─────────────────────────────────────────────────────
        Card(
          color: details.isPositive
              ? Colors.green.withValues(alpha: 0.15)
              : details.isNegative
                  ? Colors.red.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gain / Loss',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amount',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          'LKR ${fmt.format(details.gainLoss)}',
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
                        Text('Percentage',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          '${pctFmt.format(details.gainLossPercent)}%',
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

        // ── Cost Basis ──────────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cost Basis',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text('LKR ${fmt.format(details.costBasis)}',
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Avg Cost / Share',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      'LKR ${fmt.format(details.costBasis / (details.quantity > 0 ? details.quantity : 1))}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Price History & Forecast Chart ──────────────────────────────────
        if (details.priceHistory.isNotEmpty) ...[
          Text(
            'Price History & 30-Day Forecast',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
              child: _PriceChart(
                history: details.priceHistory,
                predictions: predictions,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Transaction History ─────────────────────────────────────────────
        if (details.transactionHistory.isNotEmpty) ...[
          Text('Transaction History',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: details.transactionHistory.length,
            itemBuilder: (context, i) {
              final ev = details.transactionHistory[i];
              final date =
                  DateTime.fromMillisecondsSinceEpoch(ev.occurredAtMs);
              final isBuy =
                  ev.eventType == 'buy' || ev.eventType == 'deposit';
              return ListTile(
                leading: Icon(
                  isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isBuy ? Colors.green : Colors.red,
                ),
                title: Text(
                    '${ev.eventType.toUpperCase()} ${ev.qty} shares'),
                subtitle:
                    Text(DateFormat('MMM dd, yyyy').format(date)),
                trailing: Text('${ev.qty} qty',
                    style: Theme.of(context).textTheme.bodySmall),
              );
            },
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Chart Widget ────────────────────────────────────────────────────────────

class _PriceChart extends StatelessWidget {
  final List<dynamic> history; // List<StockPrice>
  final List<PricePrediction> predictions;

  const _PriceChart({required this.history, required this.predictions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final fmtShort = NumberFormat('#,##0', 'en_US');

    // ── Build spot lists ───────────────────────────────────────────────────
    final actualSpots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value.closePrice as double)))
        .toList();

    final lastIdx = (history.length - 1).toDouble();

    // Prediction line starts at last actual point for seamless connection.
    final predSpots = predictions.isEmpty
        ? <FlSpot>[]
        : [
            FlSpot(lastIdx, history.last.closePrice as double),
            ...predictions.asMap().entries.map(
                  (e) => FlSpot(lastIdx + 1 + e.key, e.value.price),
                ),
          ];

    // ── All dates for x-axis labels ────────────────────────────────────────
    final allDates = [
      ...history.map(
          (p) => CseScraperService.yyyymmddToDate(p.priceDate as int)),
      ...predictions.map((p) => p.date),
    ];

    final totalPts = allDates.length;

    // Show date labels at: start, ~quarter, ~half, today, end-of-forecast.
    final labelSet = <int>{
      0,
      totalPts ~/ 4,
      history.length ~/ 2,
      history.length - 1,
      if (predictions.isNotEmpty) totalPts - 1,
    };

    // ── Price range ────────────────────────────────────────────────────────
    final allPrices = [
      ...history.map((p) => p.closePrice as double),
      if (predictions.isNotEmpty) ...predictions.map((p) => p.price),
    ];
    final minPrice = allPrices.reduce(min);
    final maxPrice = allPrices.reduce(max);
    final margin = (maxPrice - minPrice) * 0.12;
    final minY = (minPrice - margin).clamp(0.0, double.infinity);
    final maxY = maxPrice + margin;

    // ── Chart ──────────────────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _legendItem(Colors.blue, 'Actual (90d)', dashed: false),
            const SizedBox(width: 20),
            _legendItem(Colors.orange, 'Forecast (30d)', dashed: true),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 230,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (totalPts - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: theme.dividerColor.withOpacity(0.2),
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          fmtShort.format(value),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 9),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.round();
                      if (!labelSet.contains(idx)) {
                        return const SizedBox.shrink();
                      }
                      if (idx < 0 || idx >= allDates.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('MMM d').format(allDates[idx]),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Dashed vertical line marking "today" boundary
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: lastIdx,
                    color: theme.dividerColor.withOpacity(0.7),
                    strokeWidth: 1,
                    dashArray: [4, 3],
                    label: VerticalLineLabel(
                      show: true,
                      labelResolver: (_) => 'Today',
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = s.x.round();
                    final isPred = s.x > lastIdx;
                    final dateStr = (idx >= 0 && idx < allDates.length)
                        ? DateFormat('d MMM yyyy').format(allDates[idx])
                        : '';
                    return LineTooltipItem(
                      '$dateStr\nLKR ${fmt.format(s.y)}',
                      TextStyle(
                        color: isPred ? Colors.orange : Colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      children: isPred
                          ? [
                              TextSpan(
                                text: '\nforecast',
                                style: TextStyle(
                                  color: Colors.orange.withOpacity(0.75),
                                  fontSize: 9,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ]
                          : [],
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                // Actual history – solid blue
                LineChartBarData(
                  spots: actualSpots,
                  isCurved: false,
                  color: Colors.blue,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.12),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Forecast – dashed orange
                if (predSpots.length > 1)
                  LineChartBarData(
                    spots: predSpots,
                    isCurved: false,
                    color: Colors.orange,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.08),
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

        const SizedBox(height: 10),

        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${history.length}d  ·  Low: ${fmtShort.format(allPrices.reduce(min))}',
              style:
                  theme.textTheme.labelSmall?.copyWith(color: Colors.blue),
            ),
            Text(
              'High: ${fmtShort.format(allPrices.take(history.length).reduce(max))}',
              style:
                  theme.textTheme.labelSmall?.copyWith(color: Colors.blue),
            ),
            if (predictions.isNotEmpty)
              Text(
                '30d: ${fmtShort.format(predictions.last.price)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label, {required bool dashed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 10,
          child: CustomPaint(painter: _LegendLinePainter(color, dashed)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _LegendLinePainter(this.color, this.dashed);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    if (dashed) {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 5).clamp(0, size.width), y),
          paint,
        );
        x += 9;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
