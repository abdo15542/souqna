import 'package:flutter/services.dart';

/// جسر MethodChannel بسيط للمشاركة بدون أي حزمة طرف ثالثة.
class ShareLauncher {
  static const MethodChannel _ch = MethodChannel('souqna/share');
  static Future<void> shareFile(String path, String name) async {
    try {
      await _ch.invokeMethod('share', {'path': path, 'name': name});
    } on MissingPluginException {
      // إن لم يكن الجسر موجودًا (بناء قديم)، تجاهل بصمت.
    }
  }
}
