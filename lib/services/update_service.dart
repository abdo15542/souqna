import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Increase BOTH here and pubspec.yaml `version:` on every release.
const String APP_VERSION = '1.0.0';

class UpdateInfo {
  final String latestVersion;
  final String apkUrl;
  UpdateInfo(this.latestVersion, this.apkUrl);
}

class UpdateService {
  static const MethodChannel _channel = MethodChannel('souqna/installer');
  static const String _repo = 'abdo15542/souqna';

  /// Returns UpdateInfo if a newer release exists, else null.
  /// Fails SILENTLY when offline (keeps the app 100% usable offline).
  static Future<UpdateInfo?> check() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      try {
        final req = await client.getUrl(
          Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        );
        req.headers.set('User-Agent', 'souqna-updater');
        req.headers.set('Accept', 'application/vnd.github+json');
        final resp = await req.close().timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) return null;
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final tag = (data['tag_name'] ?? '').toString();
        final assets = (data['assets'] as List?) ?? const [];
        String? apkUrl;
        for (final a in assets) {
          final name = (a['name'] ?? '').toString();
          if (name.toLowerCase().endsWith('.apk')) {
            apkUrl = (a['browser_download_url'] ?? '').toString();
            break;
          }
        }
        if (tag.isEmpty || apkUrl == null || apkUrl.isEmpty) return null;
        final latest = tag.startsWith('v') ? tag.substring(1) : tag;
        if (_isNewer(latest, APP_VERSION)) return UpdateInfo(latest, apkUrl!);
        return null;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null; // offline / api error -> no prompt, app keeps working
    }
  }

  static bool _isNewer(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (int i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x > y) return true;
      if (x < y) return false;
    }
    return false;
  }

  /// Downloads the APK to the app cache dir and opens the installer.
  /// Requires the user to confirm installation (Android security rule).
  static Future<String?> install(String url) async {
    try {
      await _channel.invokeMethod<bool>('install', {'url': url});
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'فشل التنزيل/التنصيب';
    } catch (e) {
      return '$e';
    }
  }

  /// Call from UI: shows an in-app prompt when a newer release exists.
  static Future<void> maybePrompt(BuildContext context) async {
    final info = await check();
    if (info == null || !context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('نسخة جديدة متوفرة'),
        content: Text(
          'صدرت النسخة ${info.latestVersion} (لديك $APP_VERSION).\n'
          'سيتم تنزيلها وفتح شاشة التنصيب. بياناتك ستبقى محفوظة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لاحقًا')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تحديث الآن')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      final err = await install(info.apkUrl);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err == null ? 'جارٍ فتح شاشة التنصيب…' : 'خطأ: $err'),
      ));
    }
  }
}
