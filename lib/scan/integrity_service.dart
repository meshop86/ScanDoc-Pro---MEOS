import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'audit_events.dart';
import 'audit_service.dart';
import 'manifest_service.dart';
import 'quota_service.dart';
import 'tap_service.dart';
import 'tap_status.dart';

class IntegrityService {
  static const _systemUserId = 'system';
  static const _systemDisplay = 'System';

  /// Validate and auto-recover core files to keep the app stable offline.
  /// Creates missing audit logs, manifest files, and quota state safely.
  static Future<void> validateAndRecover() async {
    await _ensureQuotaState();
    await _ensureTapArtifacts();
  }

  static Future<void> _ensureQuotaState() async {
    final result = await QuotaService.ensureState();
    if (result.recreated) {
      await AuditService.logAction(
        tapCode: 'GLOBAL',
        userId: _systemUserId,
        userDisplayName: _systemDisplay,
        action: AuditEventType.systemRecover,
        eventType: AuditEventType.systemRecover,
        target: 'quota_state.json',
        meta: result.state,
      );
    }
  }

  static Future<void> _ensureTapArtifacts() async {
    final taps = await TapService.listTaps();
    for (final tap in taps) {
      final status = await TapService.getTapStatus(tap);
      bool recovered = false;

      // audit_log.json
      final docsDir = await getApplicationDocumentsDirectory();
      final auditFile = File('${docsDir.path}/HoSoXe/$tap/audit_log.json');
      final auditExisted = await auditFile.exists();
      await AuditService.ensureAuditFile(tap);
      if (!auditExisted) recovered = true;

      // tap_manifest.json
      final tapManifestFile = File('${docsDir.path}/HoSoXe/$tap/tap_manifest.json');
      final manifestData = await ManifestService.readManifestFile(tapManifestFile);
      if (manifestData.isEmpty) {
        final user = UserInfo(userId: _systemUserId, displayName: _systemDisplay);
        final bo = await TapService.listBoHoSo(tap);
        await ManifestService.writeTapManifest(
          tapCode: tap,
          userInfo: user,
          tapStatus: status,
          userLabels: {},
          systemLabels: {},
        );
        recovered = true;
      }

      // document manifests per hồ sơ
      final boList = await TapService.listBoHoSo(tap);
      for (final bo in boList) {
        final manifestFile = File('${docsDir.path}/HoSoXe/$tap/$bo/manifest.json');
        final docManifest = await ManifestService.readManifestFile(manifestFile);
        if (docManifest.isEmpty) {
          final user = UserInfo(userId: _systemUserId, displayName: _systemDisplay);
          await ManifestService.writeManifest(
            bienSo: bo,
            userInfo: user,
            tapCode: tap,
          );
          recovered = true;
        }
      }

      if (recovered) {
        await AuditService.logAction(
          tapCode: tap,
          userId: _systemUserId,
          userDisplayName: _systemDisplay,
          action: AuditEventType.systemRecover,
          eventType: AuditEventType.systemRecover,
          target: tap,
          caseState: status.value,
        );
      }
    }
  }
}
