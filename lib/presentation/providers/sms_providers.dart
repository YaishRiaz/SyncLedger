import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/data/sms/sms_plugin.dart';
import 'package:sync_ledger/domain/services/sms_ingestion_service.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';
import 'package:sync_ledger/presentation/providers/investment_providers.dart';
import 'package:sync_ledger/presentation/providers/transaction_providers.dart';

class SmsImportState {
  const SmsImportState({
    this.isImporting = false,
    this.isListening = false,
    this.importedCount = 0,
    this.parsedCount = 0,
    this.statusText = 'Ready to import',
  });

  final bool isImporting;
  final bool isListening;
  final int importedCount;
  final int parsedCount;
  final String statusText;

  SmsImportState copyWith({
    bool? isImporting,
    bool? isListening,
    int? importedCount,
    int? parsedCount,
    String? statusText,
  }) {
    return SmsImportState(
      isImporting: isImporting ?? this.isImporting,
      isListening: isListening ?? this.isListening,
      importedCount: importedCount ?? this.importedCount,
      parsedCount: parsedCount ?? this.parsedCount,
      statusText: statusText ?? this.statusText,
    );
  }
}

class SmsImportNotifier extends StateNotifier<SmsImportState> {
  SmsImportNotifier(this._ref) : super(const SmsImportState()) {
    _initializeListener();
  }

  final Ref _ref;
  StreamSubscription? _smsSubscription;

  // Auto-start listener when notifier is created
  Future<void> _initializeListener() async {
    await Future.delayed(Duration.zero); // Let the widget tree build first
    final granted = await SmsPlugin.requestSmsPermission();
    if (granted) {
      await startListening();
    }
  }

  /// [sinceMs] — only import messages received on or after this timestamp.
  /// Pass null to import all messages in the inbox.
  Future<void> importSms({int? sinceMs}) async {
    state = state.copyWith(
      isImporting: true,
      statusText: 'Requesting permission...',
    );

    final granted = await SmsPlugin.requestSmsPermission();
    if (!granted) {
      state = state.copyWith(
        isImporting: false,
        statusText: 'SMS permission denied',
      );
      return;
    }

    state = state.copyWith(statusText: 'Reading SMS inbox...');

    final messages = await SmsPlugin.getInboxMessages(
      sinceTimestampMs: sinceMs,
    );
    final service = SmsIngestionService(
      db: _ref.read(databaseProvider),
      registry: _ref.read(parserRegistryProvider),
      debugMode: _ref.read(debugModeProvider),
    );

    final profileId = await _ref.read(activeProfileIdProvider.future);

    int imported = 0;
    int parsed = 0;
    for (final msg in messages) {
      final result = await service.ingestSms(msg, profileId: profileId);
      if (result != null) {
        imported++;
        if (result) parsed++;
      }
    }

    state = state.copyWith(
      isImporting: false,
      importedCount: state.importedCount + imported,
      parsedCount: state.parsedCount + parsed,
      statusText: 'Ready to import',
    );

    // Refresh all data-dependent providers so UI reflects newly ingested data
    _ref.invalidate(holdingsProvider);
    _ref.invalidate(investmentEventsProvider);
    _ref.invalidate(accountsProvider);
    _ref.invalidate(uniqueAccountsProvider);
    _ref.invalidate(profileAccountsProvider);
    _ref.invalidate(familyHoldingsProvider);
    _ref.invalidate(monthlyCashflowProvider);
  }

  Future<void> startListening() async {
    if (state.isListening) return; // Already listening

    final granted = await SmsPlugin.requestSmsPermission();
    if (!granted) return;

    await SmsPlugin.startSmsListener();
    
    final profileId = await _ref.read(activeProfileIdProvider.future);
    
    _smsSubscription = SmsPlugin.streamNewSms().listen((msg) async {
      final service = SmsIngestionService(
        db: _ref.read(databaseProvider),
        registry: _ref.read(parserRegistryProvider),
        debugMode: _ref.read(debugModeProvider),
      );
      await service.ingestSms(msg, profileId: profileId);

      // Refresh account and investment providers when new SMS is ingested
      _ref.invalidate(accountsProvider);
      _ref.invalidate(uniqueAccountsProvider);
      _ref.invalidate(profileAccountsProvider);
      _ref.invalidate(holdingsProvider);
      _ref.invalidate(familyHoldingsProvider);
      _ref.invalidate(investmentEventsProvider);
    });

    state = state.copyWith(
      isListening: true,
      statusText: 'Listening for new SMS...',
    );
  }

  Future<void> stopListening() async {
    await _smsSubscription?.cancel();
    await SmsPlugin.stopSmsListener();
    state = state.copyWith(
      isListening: false,
      statusText: 'Listener stopped',
    );
  }

  @override
  void dispose() {
    _smsSubscription?.cancel();
    super.dispose();
  }
}

final smsImportStateProvider =
    StateNotifierProvider<SmsImportNotifier, SmsImportState>(
  (ref) => SmsImportNotifier(ref),
);
