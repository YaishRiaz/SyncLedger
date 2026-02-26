import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/core/theme.dart';
import 'package:sync_ledger/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:sync_ledger/presentation/screens/home/home_screen.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

class SyncLedgerApp extends ConsumerWidget {
  const SyncLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasOnboarded = ref.watch(hasOnboardedProvider);

    return MaterialApp(
      title: 'SyncLedger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: hasOnboarded.when(
        data: (done) => done ? const HomeScreen() : const OnboardingScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const OnboardingScreen(),
      ),
    );
  }
}
