import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sync_ledger/domain/models/sms_message.dart';
import 'package:sync_ledger/core/constants.dart';

abstract final class SmsPlugin {
  static const _channel = MethodChannel('com.syncledger.sms/methods');
  static const _eventChannel = EventChannel('com.syncledger.sms/events');

  static Future<bool> requestSmsPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('requestSmsPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<List<SmsMessage>> getInboxMessages({int? sinceTimestampMs}) async {
    try {
      final args = <String, dynamic>{};
      if (sinceTimestampMs != null) {
        args['sinceTimestampMs'] = sinceTimestampMs;
      }
      final result = await _channel.invokeListMethod<Map>('getInboxMessages', args);
      if (result == null) return [];

      return result
          .map((m) {
            final sender = (m['sender'] as String?) ?? '';
            final normalizedSender = sender.replaceAll('+', ' ').trim();
            final isKnown = AppConstants.knownSmsSenders.any(
              (s) => normalizedSender.toUpperCase().contains(s.toUpperCase()),
            );
            if (!isKnown) return null;
            return SmsMessage(
              sender: sender,
              body: (m['body'] as String?) ?? '',
              receivedAtMs: (m['date'] as int?) ?? 0,
            );
          })
          .whereType<SmsMessage>()
          .toList();
    } on PlatformException {
      return [];
    }
  }

  static Future<void> startSmsListener() async {
    await _channel.invokeMethod('startSmsListener');
  }

  static Future<void> stopSmsListener() async {
    await _channel.invokeMethod('stopSmsListener');
  }

  static Stream<SmsMessage> streamNewSms() {
    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) {
      final m = event as Map;
      return SmsMessage(
        sender: (m['sender'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        receivedAtMs: (m['date'] as int?) ??
            DateTime.now().millisecondsSinceEpoch,
      );
    }).where((msg) {
      final normalizedSender = msg.sender.replaceAll('+', ' ').trim();
      return AppConstants.knownSmsSenders.any(
        (s) => normalizedSender.toUpperCase().contains(s.toUpperCase()),
      );
    });
  }
}
