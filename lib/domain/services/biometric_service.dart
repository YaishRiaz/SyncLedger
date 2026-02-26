import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_ledger/core/constants.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> authenticate({String reason = 'Unlock SyncLedger'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefKeys.appLockEnabled) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.appLockEnabled, enabled);
  }
}
