import 'package:flutter/services.dart';

class BiometricService {
  static const MethodChannel _channel = MethodChannel('souqna/biometric');

  /// هل الجهاز يدعم البصمة؟
  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// اطلب فحص البصمة. يرجع true إذا نجح الفحص.
  static Future<bool> authenticate(String promptMessage) async {
    try {
      final result = await _channel.invokeMethod<bool>('authenticate', {'message': promptMessage});
      return result ?? false;
    } on PlatformException catch (e) {
      print('Biometric error: ${e.code} - ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }
}
