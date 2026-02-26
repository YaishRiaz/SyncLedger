import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_ledger/core/constants.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/parsers/parser_registry.dart';
import 'package:uuid/uuid.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main with ProviderScope');
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final parserRegistryProvider = Provider<ParserRegistry>((ref) {
  return ParserRegistry();
});

final hasOnboardedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(PrefKeys.hasOnboarded) ?? false;
});

final debugModeProvider = StateProvider<bool>((ref) => false);

// Profile ID provider - creates one if doesn't exist
final activeProfileIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  String? profileId = prefs.getString(PrefKeys.profileId);
  if (profileId == null) {
    profileId = const Uuid().v4();
    await prefs.setString(PrefKeys.profileId, profileId);
    
    // Also create display name
    final deviceId = prefs.getString(PrefKeys.deviceId) ?? const Uuid().v4();
    await prefs.setString(PrefKeys.deviceId, deviceId);
    await prefs.setString(PrefKeys.displayName, 'My Phone');
  }
  return profileId;
});

// App lock enabled provider
final appLockEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(PrefKeys.appLockEnabled) ?? false;
});
