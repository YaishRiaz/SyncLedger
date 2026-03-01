import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:sync_ledger/presentation/providers/investment_providers.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';
import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/presentation/screens/stocks/stock_detail_screen.dart';

class StocksScreen extends ConsumerStatefulWidget {
  const StocksScreen({super.key});

  @override
  ConsumerState<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends ConsumerState<StocksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _portfolioChartDays = 30;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Auto-fetch prices on first load
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPortfolio());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshPortfolio() async {
    setState(() => _isRefreshing = true);
    try {
      // Fetch latest prices from CSE, store them, then recalculate portfolio
      final calculator = ref.read(portfolioCalculatorProvider);
      final activeId = await ref.read(activeProfileIdProvider.future);
      await calculator.updatePricesAndRecalculatePortfolio([activeId]);

      // Invalidate related providers to refresh UI
      ref.invalidate(portfolioValueHistoryProvider);
      ref.invalidate(totalPortfolioValueProvider);
      ref.invalidate(latestPortfolioValueProvider);
      ref.invalidate(holdingsProvider);
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final holdings = ref.watch(holdingsProvider);
    final events = ref.watch(investmentEventsProvider);
    final portfolioHistory = ref.watch(portfolioValueHistoryProvider(_portfolioChartDays));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Holdings'),
            Tab(text: 'Portfolio Value'),
            Tab(text: 'Activity'),
          ],
          labelColor: theme.colorScheme.primary,
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshPortfolio,
            tooltip: 'Refresh portfolio value',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Holdings Tab
          holdings.when(
            data: (list) {
              if (list.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refreshPortfolio,
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
                onRefresh: _refreshPortfolio,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final h = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${h.qty} shares'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StockDetailScreen(symbol: h.symbol),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),

          // Portfolio Value Graph Tab
          portfolioHistory.when(
            data: (history) {
              if (history.length < 2) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.trending_up_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        history.isEmpty
                            ? 'No portfolio data yet'
                            : 'LKR ${history.first.totalValue.toStringAsFixed(2)}',
                        style: history.isEmpty
                            ? null
                            : theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        history.isEmpty
                            ? 'Tap refresh to fetch current prices'
                            : 'Refresh daily to build portfolio history',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Period Selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPeriodButton('30D', 30, theme),
                          _buildPeriodButton('90D', 90, theme),
                          _buildPeriodButton('6M', 180, theme),
                          _buildPeriodButton('1Y', 365, theme),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Chart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      child: SizedBox(
                        height: 250,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: history
                                    .asMap()
                                    .entries
                                    .map((e) =>
                                        FlSpot(e.key.toDouble(), e.value.totalValue))
                                    .toList(),
                                isCurved: true,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.withOpacity(0.6),
                                    Colors.cyan.withOpacity(0.3),
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
                  const SizedBox(height: 16),

                  // Stats
                  if (history.isNotEmpty)
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
                                  'Latest Value',
                                  style: theme.textTheme.labelSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'LKR ${NumberFormat('#,##0.00').format(history.last.totalValue)}',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Change (${_portfolioChartDays}d)',
                                  style: theme.textTheme.labelSmall,
                                ),
                                const SizedBox(height: 4),
                                if (history.length > 1)
                                  Text(
                                    '${(history.last.totalValue - history.first.totalValue).toStringAsFixed(2)} LKR (${((history.last.totalValue - history.first.totalValue) / history.first.totalValue * 100).toStringAsFixed(2)}%)',
                                    style: TextStyle(
                                      color: history.last.totalValue >= history.first.totalValue
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),

          // Activity Tab
          events.when(
            data: (list) {
              if (list.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refreshPortfolio,
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
                onRefresh: _refreshPortfolio,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final ev = list[i];
                    final isBuy = ev.eventType == 'buy' || ev.eventType == 'deposit';
                    final date = DateTime.fromMillisecondsSinceEpoch(ev.occurredAtMs);
                    return ListTile(
                      leading: Icon(
                        isBuy ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: isBuy ? Colors.green : Colors.red,
                        size: 28,
                      ),
                      title: Text(
                        '${ev.eventType.toUpperCase()} ${ev.symbol}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              isBuy ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int days, ThemeData theme) {
    final isSelected = _portfolioChartDays == days;
    return OutlinedButton(
      onPressed: () {
        setState(() => _portfolioChartDays = days);
        ref.invalidate(portfolioValueHistoryProvider);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? theme.colorScheme.primary : Colors.transparent,
        side: BorderSide(
          color:
              isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
