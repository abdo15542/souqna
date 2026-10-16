import 'dart:io';

import 'package:path/path.dart' as p;

import '../db/database_helper.dart';

class BackupService {
  static Directory _dir() {
    final base = p.dirname(DatabaseHelper.instance.dbPath);
    final d = Directory(p.join(base, 'backups'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<String> createBackup() async {
    await DatabaseHelper.instance.checkpoint();
    final src = File(DatabaseHelper.instance.dbPath);
    final name =
        'souqna_${DateTime.now().millisecondsSinceEpoch}.db';
    await src.copy(p.join(_dir().path, name));
    return name;
  }

  static List<String> listBackups() {
    final files = _dir()
        .listSync()
        .whereType<File>()
        .map((e) => p.basename(e.path))
        .toList();
    files.sort();
    return files;
  }

  static Future<void> restoreBackup(String name) async {
    await DatabaseHelper.instance.close();
    final src = File(p.join(_dir().path, name));
    await src.copy(DatabaseHelper.instance.dbPath);
    await DatabaseHelper.instance.reopen();
  }

  static void deleteBackup(String name) {
    final f = File(p.join(_dir().path, name));
    if (f.existsSync()) f.deleteSync();
  }
}
