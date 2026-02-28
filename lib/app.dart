import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/core/theme.dart';
import 'package:sync_ledger/domain/services/biometric_service.dart';
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
        data: (done) =>
            done ? const AppLockGate(child: HomeScreen()) : const OnboardingScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const OnboardingScreen(),
      ),
    );
  }
}

// ─── App Lock Gate ────────────────────────────────────────────────────────────

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _checking = true;
  bool _isAuthenticating = false;
  bool _biometricEnabled = false; // cached so lifecycle handler can use it sync

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndAuthenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock on background only when lock is enabled and we are not mid-auth.
    // (The biometric overlay can briefly pause the app on some devices.)
    if (state == AppLifecycleState.paused &&
        !_locked &&
        !_isAuthenticating &&
        _biometricEnabled) {
      if (mounted) setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed &&
        _locked &&
        !_isAuthenticating) {
      // Re-read the setting: user may have toggled it off in Settings.
      _checkAndAuthenticate();
    }
  }

  Future<void> _checkAndAuthenticate() async {
    final enabled = await BiometricService.isEnabled();
    _biometricEnabled = enabled; // update cache
    if (!enabled) {
      if (mounted) setState(() { _locked = false; _checking = false; });
      return;
    }
    if (mounted) setState(() { _locked = true; _checking = false; });
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return; // Prevent concurrent calls
    _isAuthenticating = true;
    final success = await BiometricService.authenticate(
      reason: 'Unlock SyncLedger',
    );
    _isAuthenticating = false;
    if (success && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_locked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'SyncLedger is locked',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock with Biometrics'),
              ),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
