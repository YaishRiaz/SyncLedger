import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_ledger/core/constants.dart';
import 'package:sync_ledger/data/sync/sync_client.dart';
import 'package:sync_ledger/presentation/providers/app_providers.dart';

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

    const serverUrl = 'http://192.168.1.100:${AppConstants.syncServerDefaultPort}';

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
      }
      return success;
    } catch (e) {
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
