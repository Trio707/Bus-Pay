import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ProfilePhotoCache {
  static Future<Directory> _dir() async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/profile-photos');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    return folder;
  }

  static String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static Future<File> fileFor(String userId, String updatedAt) async {
    final folder = await _dir();
    return File('${folder.path}/${_safe(userId)}-${_safe(updatedAt)}.jpg');
  }

  static Future<void> remember(String userId, String updatedAt, List<int> bytes) async {
    final folder = await _dir();
    final prefix = '${_safe(userId)}-';
    for (final entry in folder.listSync()) {
      if (entry is File && entry.uri.pathSegments.last.startsWith(prefix)) {
        entry.deleteSync();
      }
    }
    final file = await fileFor(userId, updatedAt);
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<void> forget(String userId) async {
    final folder = await _dir();
    final prefix = '${_safe(userId)}-';
    if (!folder.existsSync()) return;
    for (final entry in folder.listSync()) {
      if (entry is File && entry.uri.pathSegments.last.startsWith(prefix)) {
        entry.deleteSync();
      }
    }
  }
}
