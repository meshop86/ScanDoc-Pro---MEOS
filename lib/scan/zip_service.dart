import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'manifest_service.dart';
import 'audit_service.dart';
import 'tap_status.dart';
import 'tap_service.dart';
import 'user_service.dart';

/// ZIP service - native iOS
/// Nén thư mục HoSoXe/<bienSo>/ hoặc HoSoXe/<tapCode>/ thành .zip
class ZipService {
  static const _channel = MethodChannel('com.bienso.zip/native');

  /// Zip hồ sơ theo biển số (deprecated - dùng zipTap thay thế)
  /// Returns zip path hoặc throw nếu lỗi
  static Future<String> zipHoso(String bienSo) async {
    if (bienSo.trim().isEmpty) {
      throw Exception('Biển số trống');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final folderPath = '${docsDir.path}/HoSoXe/$bienSo';
    final zipPath = '${docsDir.path}/HoSoXe/$bienSo.zip';

    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      throw Exception('Thư mục hồ sơ không tồn tại');
    }

    final args = {
      'bienSo': bienSo,
      'folderPath': folderPath, // optional cho native
      'zipPath': zipPath,       // optional cho native
    };

    final String? path = await _channel.invokeMethod<String>('zip_folder', args);
    if (path == null || path.isEmpty) {
      throw Exception('ZIP thất bại');
    }
    return path;
  }

  /// Zip toàn bộ TAP (nhiều biển số)
  /// folderName: TAP_001 (không có HoSoXe/ prefix)
  /// zipName: biển số đầu tiên (hoặc custom)
  /// Returns zip path
  static Future<String> zipTap(String tapCode, {String? zipName, bool adminOverride = false}) async {
    final status = await TapService.getTapStatus(tapCode);
    if (!status.isExported && !adminOverride) {
      throw Exception('Chỉ zip khi TAP ở trạng thái EXPORTED');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final tapFolderPath = '${docsDir.path}/HoSoXe/$tapCode';
    final zipFileName = zipName ?? tapCode;
    final zipPath = '${docsDir.path}/HoSoXe/$zipFileName.zip';

    final folder = Directory(tapFolderPath);
    if (!await folder.exists()) {
      throw Exception('Thư mục TAP không tồn tại');
    }

    final tapManifestFile = File('$tapFolderPath/tap_manifest.json');
    if (!await tapManifestFile.exists()) {
      throw Exception('Thiếu tap_manifest.json, dừng ZIP');
    }
    final tapManifest = await ManifestService.readManifestFile(tapManifestFile);
    if (tapManifest.isEmpty) {
      throw Exception('tap_manifest.json rỗng hoặc hỏng, dừng ZIP');
    }

    final auditFile = await AuditService.ensureAuditFile(tapCode);
    if (!await auditFile.exists()) {
      throw Exception('Không thể chuẩn bị audit_log.json');
    }

    await _ensureReadme(tapCode, tapManifest: tapManifest);
    _validateDocuments(tapFolderPath, tapManifest);

    // Pass tapCode as "bienSo" to native (reuse same logic)
    final args = {
      'bienSo': tapCode,
      'folderPath': tapFolderPath,
      'zipPath': zipPath,
    };

    final String? path = await _channel.invokeMethod<String>('zip_folder', args);
    if (path == null || path.isEmpty) {
      throw Exception('ZIP TAP thất bại');
    }

    print('✓ ZIP TAP: $zipPath');
    // Audit after success
    final user = await UserService.getCurrentUser();
    final userId = user?['user_id']?.toString() ?? 'unknown';
    final action = adminOverride ? 'EXPORT_ZIP_ADMIN_OVERRIDE' : 'EXPORT_ZIP';
    await AuditService.logAction(
      tapCode: tapCode,
      userId: userId,
        userDisplayName: user?['display_name']?.toString(),
      action: action,
      eventType: action,
      target: zipFileName,
        caseState: status.value,
    );
    return path;
  }

  /// Build README.txt with context info (tap_manifest + audit presence)
  static Future<void> _ensureReadme(String tapCode, {Map<String, dynamic>? tapManifest}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tapFolder = Directory('${docsDir.path}/HoSoXe/$tapCode');
    if (!await tapFolder.exists()) return;

    final manifest = tapManifest ??
        await ManifestService.readManifestFile(
          File('${tapFolder.path}/tap_manifest.json'),
        );
    if (manifest.isEmpty) return;

    final labels = manifest['labels'] is Map ? manifest['labels'] as Map : {};
    final systemLabels = labels['system'] ?? {};
    final userLabels = labels['user'] ?? {};
    final createdBy = manifest['created_by'] ?? {};
    final createdAt = manifest['created_at'] ?? '';
    final status = manifest['tap_status'] ?? '';
    final boHoSo = manifest['bo_ho_so'] is List ? manifest['bo_ho_so'] as List : const [];

    final boList = boHoSo.map((e) {
      if (e is Map && e['bien_so'] != null) return e['bien_so'].toString();
      return e.toString();
    }).where((e) => e.isNotEmpty).toList();

    final buffer = StringBuffer();
    buffer.writeln('README - ScanDoc Pro TAP Package');
    buffer.writeln('tap_code: $tapCode');
    buffer.writeln('status: $status');
    buffer.writeln('created_at: $createdAt');
    buffer.writeln('created_by: ${createdBy.toString()}');
    buffer.writeln('labels.system: ${systemLabels.toString()}');
    buffer.writeln('labels.user: ${userLabels.toString()}');
    buffer.writeln('audit_log: audit_log.json');
    buffer.writeln('documents: mỗi thư mục biển số chứa JPG, giữ nguyên tên file');
    buffer.writeln('bo_ho_so: ${boList.join(', ')}');

    final readmeFile = File('${tapFolder.path}/README.txt');
    await readmeFile.writeAsString(buffer.toString());
  }

  /// Validate mandatory artifacts before zipping
  static void _validateDocuments(String tapFolderPath, Map<String, dynamic> tapManifest) {
    final boHoSoEntries = tapManifest['bo_ho_so'];
    final List<String> boList = [];
    if (boHoSoEntries is List) {
      for (final entry in boHoSoEntries) {
        if (entry is Map && entry['bien_so'] != null) {
          boList.add(entry['bien_so'].toString());
        }
      }
    }

    if (boList.isEmpty) {
      boList.addAll(Directory(tapFolderPath)
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split('/').last)
          .where((name) => !name.startsWith('.')));
    }

    if (boList.isEmpty) {
      throw Exception('tap_manifest không chứa bộ hồ sơ nào');
    }

    for (final bo in boList) {
      final boDir = Directory('$tapFolderPath/$bo');
      if (!boDir.existsSync()) {
        throw Exception('Thiếu thư mục hồ sơ: $bo');
      }
      final jpgs = boDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.jpg'))
          .toList();
      if (jpgs.isEmpty) {
        throw Exception('Thiếu file JPG trong bộ hồ sơ: $bo');
      }
    }
  }
}
