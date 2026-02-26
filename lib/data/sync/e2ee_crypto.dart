import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// End-to-end encryption using XChaCha20-Poly1305.
/// The familyKey is a shared symmetric key derived during QR pairing.
class E2eeCrypto {
  E2eeCrypto({required this.familyKey});

  final List<int> familyKey; // 32-byte key

  static final _algorithm = Xchacha20.poly1305Aead();

  /// Generate a random 32-byte family key.
  static Future<List<int>> generateFamilyKey() async {
    final secretKey = await _algorithm.newSecretKey();
    return secretKey.extractBytes();
  }

  /// Derive a family key from a passphrase via HKDF.
  static Future<List<int>> deriveFromPassphrase(String passphrase) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: utf8.encode('SyncLedger-FamilyKey-v1'),
      info: utf8.encode('family-encryption'),
    );
    return derivedKey.extractBytes();
  }

  /// Encrypt plaintext JSON payload. Returns {ciphertext, nonce, mac} as base64 strings.
  Future<EncryptedPayload> encrypt(String plaintext) async {
    final secretKey = SecretKey(familyKey);
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
    );

    return EncryptedPayload(
      ciphertext: base64Encode(secretBox.cipherText),
      nonce: base64Encode(secretBox.nonce),
      mac: base64Encode(secretBox.mac.bytes),
    );
  }

  /// Decrypt an encrypted payload back to plaintext JSON.
  Future<String> decrypt(EncryptedPayload payload) async {
    final secretKey = SecretKey(familyKey);
    final secretBox = SecretBox(
      base64Decode(payload.ciphertext),
      nonce: base64Decode(payload.nonce),
      mac: Mac(base64Decode(payload.mac)),
    );

    final decrypted = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(decrypted);
  }
}

class EncryptedPayload {

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedPayload(
      ciphertext: json['ciphertext'] as String,
      nonce: json['nonce'] as String,
      mac: json['mac'] as String,
    );
  }
  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  final String ciphertext;
  final String nonce;
  final String mac;

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertext,
        'nonce': nonce,
        'mac': mac,
      };
}
