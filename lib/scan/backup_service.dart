import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'google_drive_service.dart';
import 'pro_entitlement_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// BackupService - creates encrypted backups and uploads to Drive AppData (PRO only)
class BackupService {
  static const String _keyFile = 'backup_key.bin';
  static const String _backupNamePrefix = 'scandoc_backup_';

  /// Main entry: perform backup if PRO is active and account provided
  static Future<String> backupNow({required GoogleSignInAccount account}) async {
    final isPro = await ProEntitlementService.isProActive();
    if (!isPro) {
      throw Exception('PRO tier required for backup');
    }

    final zipFile = await _createBackupZip();
    final encrypted = await _encryptFile(zipFile);
    final fileName = '$_backupNamePrefix${DateTime.now().toIso8601String()}.enc';
    return GoogleDriveService.uploadAppData(account: account, bytes: encrypted, fileName: fileName);
  }

  /// Create a zip of HoSoXe folder
  static Future<File> _createBackupZip() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final root = Directory('${docsDir.path}/HoSoXe');
    if (!await root.exists()) {
      throw Exception('Không tìm thấy dữ liệu để backup');
    }

    final encoder = ZipFileEncoder();
    final outPath = '${docsDir.path}/backup_tmp.zip';
    // Remove old temp if any
    final outFile = File(outPath);
    if (await outFile.exists()) await outFile.delete();

    encoder.create(outPath);
    encoder.addDirectory(root, includeDirName: true);
    encoder.close();
    return File(outPath);
  }

  /// Encrypt file with AES-256-GCM; output bytes = nonce + cipherText + mac
  static Future<List<int>> _encryptFile(File file) async {
    final algorithm = AesGcm.with256bits();
    final keyBytes = await _loadOrCreateKey();
    final secretKey = SecretKey(keyBytes);
    final nonce = _randomNonce();
    final data = await file.readAsBytes();
    final secretBox = await algorithm.encrypt(
      data,
      secretKey: secretKey,
      nonce: nonce,
    );
    final builder = BytesBuilder();
    builder.add(nonce);
    builder.add(secretBox.cipherText);
    builder.add(secretBox.mac.bytes);
    return builder.toBytes();
  }

  static List<int> _randomNonce() {
    final random = Random.secure();
    return List<int>.generate(12, (_) => random.nextInt(256));
  }

  static Future<List<int>> _loadOrCreateKey() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final keyFile = File('${docsDir.path}/$_keyFile');
    if (await keyFile.exists()) {
      final data = await keyFile.readAsBytes();
      if (data.length == 32) return data;
    }
    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256)); // 256-bit key
    await keyFile.writeAsBytes(key, flush: true);
    return key;
  }
}
