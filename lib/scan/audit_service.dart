import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// AuditService ghi lại lịch sử thao tác offline cho từng TAP.
class AuditService {
  static const _hosoRoot = 'HoSoXe';
  static const _auditFile = 'audit_log.json';

  static Future<File> _getAuditFile(String tapCode) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$_hosoRoot/$tapCode/$_auditFile');
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('[]');
    }
    return file;
  }

  /// Ensure audit_log.json exists (no new entry is added)
  static Future<File> ensureAuditFile(String tapCode) async {
    return _getAuditFile(tapCode);
  }

  static Future<void> logAction({
    required String tapCode,
    required String userId,
    String? userDisplayName,
    required String action,
    required String target,
    String? eventType,
    String? caseState,
    String? caseName,          // New: generalized case name
    String? documentSetName,   // New: document set name
    Map<String, dynamic>? meta,
    DateTime? time,
  }) async {
    try {
      final file = await _getAuditFile(tapCode);
      List<dynamic> entries = [];
      try {
        final raw = await file.readAsString();
        final parsed = jsonDecode(raw);
        if (parsed is List) entries = parsed;
      } catch (_) {
        entries = [];
      }

      entries.add({
        'time': (time ?? DateTime.now()).toIso8601String(),
        'user': userId,
        'user_display': userDisplayName ?? '',
        'tap_code': tapCode,
        'event_type': eventType ?? action,
        'action': action,
        'target': target,
        'case_state': caseState,
        if (caseName != null) 'case_name': caseName,
        if (documentSetName != null) 'document_set': documentSetName,
        if (meta != null && meta.isNotEmpty) 'meta': meta,
      });

      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(entries));
    } catch (e) {
      // Không throw để tránh chặn flow chính; log ra console.
      print('Audit log error: $e');
    }
  }
}
