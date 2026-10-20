import '../db/database_helper.dart';
import 'biometric_service.dart';

class AuthService {
  static String _hash(String s) {
    int h = 5381;
    for (final int c in s.codeUnits) {
      h = ((h * 33) + c) & 0x7FFFFFFF;
    }
    return '${h.toRadixString(16)}:${s.length.toRadixString(16)}';
  }

  static Future<bool> isPinEnabled() async {
    final v = await DatabaseHelper.instance.getSetting('pin_enabled');
    return v == '1';
  }

  static Future<bool> isPinSet() async {
    final v = await DatabaseHelper.instance.getSetting('pin_hash');
    return v != null && v.isNotEmpty;
  }

  static Future<bool> needPin() async => await isPinEnabled() && await isPinSet();

  static Future<void> setPin(String pin) async {
    await DatabaseHelper.instance.setSetting('pin_hash', _hash(pin));
    await DatabaseHelper.instance.setSetting('pin_enabled', '1');
  }

  static Future<bool> verifyPin(String pin) async {
    final stored = await DatabaseHelper.instance.getSetting('pin_hash');
    return stored != null && stored == _hash(pin);
  }

  static Future<bool> changePin(String oldPin, String newPin) async {
    if (!await verifyPin(oldPin)) return false;
    await setPin(newPin);
    return true;
  }

  static Future<void> disablePin() async {
    await DatabaseHelper.instance.setSetting('pin_enabled', '0');
    await DatabaseHelper.instance.setSetting('pin_hash', '');
  }

  // ================= Biometric =================
  static Future<bool> isBiometricAvailable() async {
    return await BiometricService.isAvailable();
  }

  static Future<bool> authenticateWithBiometric() async {
    return await BiometricService.authenticate('أدخل البصمة لفتح سوقنا');
  }
}
