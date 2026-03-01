import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';
import 'package:sync_ledger/presentation/screens/personal/personal_dashboard.dart';
import 'package:sync_ledger/presentation/screens/personal/transactions_screen.dart';
import 'package:sync_ledger/presentation/screens/stocks/stocks_screen.dart';
import 'package:sync_ledger/presentation/screens/analytics/analytics_screen.dart';
import 'package:sync_ledger/presentation/screens/family/family_screen.dart';
import 'package:sync_ledger/presentation/screens/settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  static const _baseDestinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Transactions',
    ),
    NavigationDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: 'Stocks',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: 'Analytics',
    ),
  ];

  static const _familyDestination = NavigationDestination(
    icon: Icon(Icons.family_restroom_outlined),
    selectedIcon: Icon(Icons.family_restroom),
    label: 'Family',
  );

  static const _baseScreens = [
    PersonalDashboard(),
    TransactionsScreen(),
    StocksScreen(),
    AnalyticsScreen(),
  ];

  static const _familyScreen = FamilyScreen();

  @override
  Widget build(BuildContext context) {
    final familySyncEnabledAsync = ref.watch(familySyncEnabledProvider);
    final stockAnalysisEnabledAsync = ref.watch(enableStockAnalysisProvider);

    return familySyncEnabledAsync.when(
      data: (isFamilyEnabled) {
        return stockAnalysisEnabledAsync.when(
          data: (isStockAnalysisEnabled) {
            // Build dynamic destination and screen lists based on settings
            final destinations = [
              _baseDestinations[0], // Dashboard
              _baseDestinations[1], // Transactions
              if (isStockAnalysisEnabled) _baseDestinations[2], // Stocks (conditional)
              _baseDestinations[3], // Analytics
              if (isFamilyEnabled) _familyDestination,
            ];

            final screens = [
              _baseScreens[0], // Dashboard
              _baseScreens[1], // Transactions
              if (isStockAnalysisEnabled) _baseScreens[2], // Stocks (conditional)
              _baseScreens[3], // Analytics
              if (isFamilyEnabled) _familyScreen,
            ];

            // Adjust selected index if stocks or family were disabled
            final currentIndex = _selectedIndex;
            final maxValidIndex = screens.length - 1;
            if (currentIndex > maxValidIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => _selectedIndex = 0);
              });
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('SyncLedger'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
              body: IndexedStack(
                index: currentIndex,
                children: screens,
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                destinations: destinations,
              ),
            );
          },
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('SyncLedger')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Scaffold(
            appBar: AppBar(title: const Text('SyncLedger')),
            body: const Center(child: Text('Error loading settings')),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('SyncLedger')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('SyncLedger')),
        body: const Center(child: Text('Error loading settings')),
      ),
    );
  }
}
