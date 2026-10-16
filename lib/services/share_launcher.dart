import 'package:flutter/services.dart';

class ShareLauncher {
  static const MethodChannel _ch = MethodChannel('souqna/share');
  
  static Future<void> shareFile(String path, String name) async {
    try {
      await _ch.invokeMethod('share', {'path': path, 'name': name});
    } on MissingPluginException {
      // تجاهل بصمت إذا لم يكن الجسر موجودًا
    }
  }
}
