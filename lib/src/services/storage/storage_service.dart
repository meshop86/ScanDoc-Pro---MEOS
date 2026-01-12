import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  StorageService();

  Future<Directory> _baseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final base = Directory(p.join(docs.path, 'HoSoXe'));
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return base;
  }

  Future<Directory> ensureTapFolder(String tapCode) async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, tapCode));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> ensureBoFolder(String tapCode, String licensePlate) async {
    final tapDir = await ensureTapFolder(tapCode);
    final dir = Directory(p.join(tapDir.path, licensePlate));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> manifestFile(String tapCode) async {
    final tapDir = await ensureTapFolder(tapCode);
    return File(p.join(tapDir.path, 'manifest.json'));
  }

  Future<void> writeManifest(String tapCode, Map<String, dynamic> manifest) async {
    final file = await manifestFile(tapCode);
    await file.writeAsString(jsonEncode(manifest), flush: true);
  }

  Future<void> renameBoFolder({required String tapCode, required String oldPlate, required String newPlate}) async {
    final tapDir = await ensureTapFolder(tapCode);
    final oldDir = Directory(p.join(tapDir.path, oldPlate));
    if (await oldDir.exists()) {
      final newDir = Directory(p.join(tapDir.path, newPlate));
      await oldDir.rename(newDir.path);
    }
  }

  Future<File> docFile({required String tapCode, required String licensePlate, required String fileName}) async {
    final boDir = await ensureBoFolder(tapCode, licensePlate);
    return File(p.join(boDir.path, fileName));
  }

  Future<void> overwriteDoc({
    required String tapCode,
    required String licensePlate,
    required String fileName,
    required List<int> bytes,
  }) async {
    final file = await docFile(tapCode: tapCode, licensePlate: licensePlate, fileName: fileName);
    await file.writeAsBytes(bytes, flush: true);
  }
}
