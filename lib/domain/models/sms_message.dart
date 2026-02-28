import 'dart:convert';
import 'package:crypto/crypto.dart' show md5;

class SmsMessage {
  const SmsMessage({
    required this.sender,
    required this.body,
    required this.receivedAtMs,
    this.id,
  });

  final int? id;
  final String sender;
  final String body;
  final int receivedAtMs;

  String get hash {
    final input = '$sender|$body';
    final bytes = utf8.encode(input);
    return md5.convert(bytes).toString();
  }

  DateTime get receivedAt =>
      DateTime.fromMillisecondsSinceEpoch(receivedAtMs);

  @override
  String toString() => 'SmsMessage(sender: $sender, at: $receivedAtMs)';
}
