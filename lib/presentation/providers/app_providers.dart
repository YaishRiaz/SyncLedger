import 'dart:convert';
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

final familySyncEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(PrefKeys.familySyncEnabled) ?? false; // Default: OFF
});

// ─── Profiles ───────────────────────────────────────────────────────────────

class ProfileEntry {
  const ProfileEntry({required this.id, required this.name});
  final String id;
  final String name;

  Map<String, String> toJson() => {'id': id, 'name': name};

  static ProfileEntry fromJson(Map<String, dynamic> m) =>
      ProfileEntry(id: m['id'] as String, name: m['name'] as String);
}

class ProfileListNotifier extends StateNotifier<List<ProfileEntry>> {
  ProfileListNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PrefKeys.profiles);
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => ProfileEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    }

    if (state.isEmpty) {
      // Bootstrap: create default profile from existing profileId pref (or new)
      String? existingId = prefs.getString(PrefKeys.profileId);
      existingId ??= const Uuid().v4();
      final defaultProfile = ProfileEntry(id: existingId, name: 'My Account');
      await _persist([defaultProfile]);
      await prefs.setString(PrefKeys.profileId, existingId);
      // Ensure deviceId exists
      if (prefs.getString(PrefKeys.deviceId) == null) {
        await prefs.setString(PrefKeys.deviceId, const Uuid().v4());
      }
    }

    // Ensure activeProfileId is set
    if (prefs.getString(PrefKeys.profileId) == null && state.isNotEmpty) {
      await prefs.setString(PrefKeys.profileId, state.first.id);
    }
  }

  Future<void> addProfile(String name) async {
    final newId = const Uuid().v4();
    final updated = [...state, ProfileEntry(id: newId, name: name)];
    await _persist(updated);
  }

  Future<void> switchProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.profileId, id);
    // Emit new state reference so activeProfileIdProvider (which watches this) re-evaluates
    state = [...state];
  }

  Future<void> deleteProfile(String id) async {
    if (state.length <= 1) return; // must keep at least one
    final updated = state.where((p) => p.id != id).toList();
    // If deleted profile was active, switch to first remaining
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(PrefKeys.profileId) == id) {
      await prefs.setString(PrefKeys.profileId, updated.first.id);
    }
    await _persist(updated);
  }

  Future<void> renameProfile(String id, String newName) async {
    final updated = state
        .map((p) => p.id == id ? ProfileEntry(id: id, name: newName) : p)
        .toList();
    await _persist(updated);
  }

  Future<void> _persist(List<ProfileEntry> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        PrefKeys.profiles, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    state = profiles;
  }
}

final profileListProvider =
    StateNotifierProvider<ProfileListNotifier, List<ProfileEntry>>(
  (ref) => ProfileListNotifier(),
);

/// The currently active profile UUID
final activeProfileIdProvider = FutureProvider<String>((ref) async {
  // Watch profileListProvider so we re-evaluate when profile switches
  ref.watch(profileListProvider);
  final prefs = await SharedPreferences.getInstance();
  String? profileId = prefs.getString(PrefKeys.profileId);
  if (profileId == null) {
    profileId = const Uuid().v4();
    await prefs.setString(PrefKeys.profileId, profileId);
    await prefs.setString(PrefKeys.deviceId, const Uuid().v4());
    await prefs.setString(PrefKeys.displayName, 'My Account');
  }
  return profileId;
});

// App lock enabled provider
final appLockEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(PrefKeys.appLockEnabled) ?? false;
});

// Stock analysis enabled provider (default: true)
final enableStockAnalysisProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(PrefKeys.enableStockAnalysis) ?? true;
});

// ─── Accounts / Bank Balances ────────────────────────────────────────────────

/// All bank accounts with their latest balances
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllAccounts();
});

/// Unique accounts across all profiles (deduplicated by institution + last4)
/// Shows only one entry per unique account regardless of how many profiles it's assigned to.
/// Used in Settings Account Management UI.
final uniqueAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getUniqueAccountsAcrossProfiles();
});

/// Selected institution filter for dashboard. null = All Banks.
final selectedBankProvider = StateProvider<String?>((ref) => null);

// ─── Profile-Based Account Management ────────────────────────────────────────

/// All accounts assigned to the currently active profile.
/// Returns empty list if no accounts are assigned to the profile.
/// Auto-updates when profile switches.
final profileAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final db = ref.watch(databaseProvider);
  final activeProfileId = await ref.watch(activeProfileIdProvider.future);
  return db.getAccountsByProfile(activeProfileId);
});
