import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

import 'manifest_service.dart';
import 'tap_service.dart';
import 'audit_service.dart';
import 'tap_status.dart';
import 'user_service.dart';
import 'audit_events.dart';
import 'quota_service.dart';

/// PdfService - tạo PDF cho 1 hồ sơ (bienSo)
class PdfService {
  /// Tạo PDF từ các trang scan (theo thứ tự) cho một hồ sơ
  /// Chỉ cho phép khi TAP ở trạng thái EXPORTED hoặc adminOverride = true
  static Future<File> generateDocumentPdf({
    required String bienSo,
    String? tapCode,
    bool adminOverride = false,
  }) async {
    TapStatus? tapStatus;

    // Guard state
    if (tapCode != null) {
      tapStatus = await TapService.getTapStatus(tapCode);
      if (!tapStatus.isExported && !adminOverride) {
        throw Exception('Chỉ export PDF khi TAP ở trạng thái EXPORTED');
      }
    }

    // Quota check (skip when adminOverride)
    if (!adminOverride) {
      final currentUser = await UserService.getCurrentUser();
      final quota = await QuotaService.checkAndConsumeExport(
        userId: currentUser?['user_id'] ?? 'unknown',
        userDisplayName: currentUser?['display_name'],
        tapCode: tapCode,
      );
      if (!quota.allowed) {
        throw Exception(quota.message);
      }
    }

    // Load manifest + labels + user info
    final docs = await getApplicationDocumentsDirectory();
    final manifestFilePath = tapCode != null
        ? '${docs.path}/HoSoXe/$tapCode/$bienSo/manifest.json'
        : '${docs.path}/HoSoXe/$bienSo/manifest.json';
    final manifestFile = File(manifestFilePath);
    if (!await manifestFile.exists()) {
      throw Exception('Thiếu manifest.json cho $bienSo');
    }
    final manifest = await ManifestService.readManifestFile(manifestFile);
    if (manifest.isEmpty) {
      throw Exception('manifest.json rỗng hoặc hỏng cho $bienSo');
    }

    final createdBy = manifest['created_by'] ?? {};
    final labels = manifest['labels'] ?? {};
    final systemLabels = labels is Map ? (labels['system'] ?? {}) : {};
    final userLabels = labels is Map ? (labels['user'] ?? {}) : {};
    final createdAt = manifest['created_at']?.toString() ?? '';
    final documents = manifest['documents'];
    if (documents is! List || documents.isEmpty) {
      throw Exception('manifest.json không có documents cho $bienSo');
    }

    final baseDir = tapCode != null
        ? '${docs.path}/HoSoXe/$tapCode/$bienSo'
        : '${docs.path}/HoSoXe/$bienSo';

    // Keep deterministic order: sort by doc type name, pages already sorted in manifest
    final sortedDocs = List<Map<String, dynamic>>.from(
      documents.whereType<Map<String, dynamic>>(),
    )
      ..sort((a, b) => (a['type'] ?? '').toString().compareTo((b['type'] ?? '').toString()));

    final List<File> pageFiles = [];
    for (final doc in sortedDocs) {
      final pages = doc['pages'];
      if (pages is! List || pages.isEmpty) continue;
      for (final page in pages) {
        final pageName = page.toString();
        final file = File('$baseDir/$pageName');
        if (!file.existsSync()) {
          throw Exception('Thiếu file trang: $pageName');
        }
        pageFiles.add(file);
      }
    }

    if (pageFiles.isEmpty) {
      throw Exception('Không có trang JPG để tạo PDF cho $bienSo');
    }

    final pdf = pw.Document();
    for (final file in pageFiles) {
      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);
      final tapLabel = systemLabels['tap_code'] ?? tapCode ?? 'standalone';
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('TAP: $tapLabel', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Biển số: $bienSo', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Created at: $createdAt', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('User: ${createdBy['display_name'] ?? ''} (${createdBy['user_id'] ?? ''})', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Labels system: ${systemLabels.toString()}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Labels user: ${userLabels.toString()}', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final outputPath = tapCode != null
        ? '${docs.path}/HoSoXe/$tapCode/$bienSo/$bienSo.pdf'
        : '${docs.path}/HoSoXe/$bienSo/$bienSo.pdf';
    final outFile = File(outputPath);
    await outFile.writeAsBytes(await pdf.save());

    if (tapCode != null) {
      final currentUser = await UserService.getCurrentUser();
      final userId = currentUser?['user_id']?.toString() ?? createdBy['user_id']?.toString() ?? 'unknown';
      final action = adminOverride ? AuditEventType.exportPdfAdmin : AuditEventType.exportPdf;
      await AuditService.logAction(
        tapCode: tapCode,
        userId: userId,
        userDisplayName: currentUser?['display_name']?.toString() ?? createdBy['display_name']?.toString(),
        action: action,
        eventType: action,
        target: '$bienSo.pdf',
        caseState: tapStatus?.value ?? TapStatus.exported.value,
      );
    }
    return outFile;
  }
}
