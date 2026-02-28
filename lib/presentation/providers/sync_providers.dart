import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_ledger/core/constants.dart';
import 'package:sync_ledger/data/sync/sync_client.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

/// Validates and normalizes a server URL.
/// Returns a tuple of (isValid, normalizedUrl).
/// Adds http:// prefix if missing and appends default port if omitted.
(bool, String) validateAndNormalizeServerUrl(String input) {
  if (input.trim().isEmpty) {
    return (false, '');
  }

  String url = input.trim();

  // Add http:// if no protocol specified
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'http://$url';
  }

  // Check if port is specified
  if (!url.contains(':') || url.lastIndexOf(':') <= url.lastIndexOf('/')) {
    // No port found, add default port
    if (url.endsWith('/')) {
      url = '${url}8742';
    } else {
      url = '$url:8742';
    }
  }

  return (true, url);
}

class SyncState {
  const SyncState({
    this.isPaired = false,
    this.isSyncing = false,
    this.lastSyncAt,
    this.groupId,
    this.serverUrl,
  });

  final bool isPaired;
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? groupId;
  final String? serverUrl;

  SyncState copyWith({
    bool? isPaired,
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? groupId,
    String? serverUrl,
  }) {
    return SyncState(
      isPaired: isPaired ?? this.isPaired,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      groupId: groupId ?? this.groupId,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier(this._ref) : super(const SyncState()) {
    _loadState();
  }

  final Ref _ref;

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final groupId = prefs.getString(PrefKeys.familyGroupId);
    final serverUrl = prefs.getString(PrefKeys.syncServerUrl);
    if (groupId != null && serverUrl != null) {
      state = state.copyWith(
        isPaired: true,
        groupId: groupId,
        serverUrl: serverUrl,
      );
    }
  }

  Future<String> createPairingQr() async {
    final prefs = await SharedPreferences.getInstance();
    final groupId = const Uuid().v4();
    final deviceId =
        prefs.getString(PrefKeys.deviceId) ?? const Uuid().v4();
    await prefs.setString(PrefKeys.deviceId, deviceId);

    // Get configured server URL or use default
    String serverUrl = prefs.getString(PrefKeys.syncServerUrl) ??
        'http://127.0.0.1:${AppConstants.syncServerDefaultPort}';

    try {
      final client = SyncClient(serverUrl: serverUrl);
      final pairingToken = await client.startPairing(groupId, deviceId);

      await prefs.setString(PrefKeys.familyGroupId, groupId);
      await prefs.setString(PrefKeys.syncServerUrl, serverUrl);

      state = state.copyWith(
        isPaired: true,
        groupId: groupId,
        serverUrl: serverUrl,
      );

      return jsonEncode({
        'serverUrl': serverUrl,
        'groupId': groupId,
        'pairingToken': pairingToken,
        'deviceId': deviceId,
      });
    } catch (e) {
      print('ERROR: createPairingQr failed: $e');
      rethrow;
    }
  }

  Future<bool> joinWithQr(String qrPayload) async {
    try {
      final data = jsonDecode(qrPayload) as Map<String, dynamic>;
      final serverUrl = data['serverUrl'] as String;
      final groupId = data['groupId'] as String;
      final pairingToken = data['pairingToken'] as String;

      final prefs = await SharedPreferences.getInstance();
      final deviceId =
          prefs.getString(PrefKeys.deviceId) ?? const Uuid().v4();
      await prefs.setString(PrefKeys.deviceId, deviceId);

      print('DEBUG: Attempting to join with server=$serverUrl, groupId=$groupId, pairingToken=$pairingToken');

      final client = SyncClient(serverUrl: serverUrl);
      final success =
          await client.finishPairing(groupId, deviceId, pairingToken);

      if (success) {
        await prefs.setString(PrefKeys.familyGroupId, groupId);
        await prefs.setString(PrefKeys.syncServerUrl, serverUrl);
        state = state.copyWith(
          isPaired: true,
          groupId: groupId,
          serverUrl: serverUrl,
        );
        print('DEBUG: Pairing successful!');
      } else {
        print('ERROR: finishPairing returned false');
      }
      return success;
    } catch (e) {
      print('ERROR: joinWithQr failed: $e');
      return false;
    }
  }

  Future<void> syncNow() async {
    if (!state.isPaired || state.serverUrl == null) return;
    state = state.copyWith(isSyncing: true);

    try {
      final db = _ref.read(databaseProvider);
      final client = SyncClient(serverUrl: state.serverUrl!);

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(PrefKeys.deviceId)!;
      final lastSeq = prefs.getInt(PrefKeys.lastSyncSeq) ?? 0;

      final localChanges = await db.getChangesSince(deviceId, lastSeq);
      if (localChanges.isNotEmpty) {
        await client.pushChanges(state.groupId!, deviceId, localChanges);
      }

      final remoteChanges = await client.pullChanges(
        state.groupId!,
        deviceId,
        lastSeq,
      );
      if (remoteChanges.isNotEmpty) {
        await db.applyRemoteChanges(remoteChanges);
        final maxSeq = remoteChanges
            .map((c) => c.seq)
            .reduce((a, b) => a > b ? a : b);
        await prefs.setInt(PrefKeys.lastSyncSeq, maxSeq);
      }

      state = state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isSyncing: false);
    }
  }
}

final syncStateProvider =
    StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(ref),
);

/// Provides the configured server URL.
/// Reads from SharedPreferences or returns default if not configured.
final serverUrlProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(PrefKeys.syncServerUrl) ??
      'http://127.0.0.1:${AppConstants.syncServerDefaultPort}';
});

/// Updates the server URL and stores it in SharedPreferences.
final serverUrlNotifierProvider =
    StateNotifierProvider<ServerUrlNotifier, String>((ref) {
  return ServerUrlNotifier(ref);
});

class ServerUrlNotifier extends StateNotifier<String> {
  ServerUrlNotifier(this._ref) : super('') {
    _loadServerUrl();
  }

  final Ref _ref;

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(PrefKeys.syncServerUrl) ??
        'http://127.0.0.1:${AppConstants.syncServerDefaultPort}';
    state = url;
  }

  Future<void> updateServerUrl(String newUrl) async {
    final (isValid, normalizedUrl) = validateAndNormalizeServerUrl(newUrl);
    if (isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefKeys.syncServerUrl, normalizedUrl);
      state = normalizedUrl;
      // Invalidate the cached FutureProvider so it reads fresh from SharedPreferences
      _ref.invalidate(serverUrlProvider);
    }
  }
}
