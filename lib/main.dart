import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/app.dart';
import 'package:sync_ledger/core/logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  runApp(
    const ProviderScope(
      child: SyncLedgerApp(),
    ),
  );
}
