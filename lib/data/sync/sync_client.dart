import 'package:dio/dio.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/core/logger.dart';

class SyncClient {
  SyncClient({required this.serverUrl}) : _dio = Dio(BaseOptions(
    baseUrl: serverUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ),);

  final String serverUrl;
  final Dio _dio;

  Future<String> startPairing(String groupId, String deviceId) async {
    try {
      final response = await _dio.post('/pair/start', data: {
        'groupId': groupId,
        'deviceId': deviceId,
      },);
      return response.data['pairingToken'] as String;
    } catch (e) {
      AppLogger.e('Pairing start failed', e);
      rethrow;
    }
  }

  Future<bool> finishPairing(
    String groupId,
    String deviceId,
    String pairingToken,
  ) async {
    try {
      final response = await _dio.post('/pair/finish', data: {
        'groupId': groupId,
        'deviceId': deviceId,
        'pairingToken': pairingToken,
      },);
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e('Pairing finish failed', e);
      return false;
    }
  }

  Future<void> pushChanges(
    String groupId,
    String deviceId,
    List<Change> changes,
  ) async {
    try {
      await _dio.post('/sync/push', data: {
        'groupId': groupId,
        'deviceId': deviceId,
        'changes': changes.map((c) => {
              'seq': c.seq,
              'entityType': c.entityType,
              'entityId': c.entityId,
              'opType': c.opType,
              'payloadCiphertext': c.payloadCiphertext,
              'payloadNonce': c.payloadNonce,
              'payloadMac': c.payloadMac,
              'createdAtMs': c.createdAtMs,
            },).toList(),
      },);
    } catch (e) {
      AppLogger.e('Push changes failed', e);
      rethrow;
    }
  }

  Future<List<Change>> pullChanges(
    String groupId,
    String deviceId,
    int sinceSeq,
  ) async {
    try {
      final response = await _dio.get('/sync/pull', queryParameters: {
        'groupId': groupId,
        'deviceId': deviceId,
        'sinceSeq': sinceSeq,
      },);

      final list = response.data['changes'] as List<dynamic>? ?? [];
      return list.map((c) {
        final m = c as Map<String, dynamic>;
        return Change(
          id: m['id'] as int? ?? 0,
          deviceId: m['deviceId'] as String,
          seq: m['seq'] as int,
          createdAtMs: m['createdAtMs'] as int,
          entityType: m['entityType'] as String,
          entityId: m['entityId'] as String,
          opType: m['opType'] as String,
          payloadCiphertext: m['payloadCiphertext'] as String?,
          payloadNonce: m['payloadNonce'] as String?,
          payloadMac: m['payloadMac'] as String?,
        );
      }).toList();
    } catch (e) {
      AppLogger.e('Pull changes failed', e);
      return [];
    }
  }
}
