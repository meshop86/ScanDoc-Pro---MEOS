import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'audit_events.dart';
import 'audit_service.dart';

class QuotaCheckResult {
  final bool allowed;
  final String message;
  final int remaining;
  final int limit;
  final Map<String, dynamic> meta;

  const QuotaCheckResult({
    required this.allowed,
    required this.message,
    required this.remaining,
    required this.limit,
    this.meta = const {},
  });
}

class QuotaStateResult {
  final Map<String, dynamic> state;
  final bool recreated;
  const QuotaStateResult({required this.state, required this.recreated});
}

/// Local-only quota tracking (offline, no backend)
class QuotaService {
  static const _fileName = 'quota_state.json';
  static const int _tapLimitPerDay = 5;
  static const int _exportLimitPerDay = 10;

  static Future<File> _getFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/$_fileName');
  }

  static Future<Map<String, dynamic>> _loadState() async {
    final file = await _getFile();
    if (!await file.exists()) {
      return {
        'date': _today(),
        'tap_used': 0,
        'export_used': 0,
      };
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    return {
      'date': _today(),
      'tap_used': 0,
      'export_used': 0,
    };
  }

  static Future<void> _saveState(Map<String, dynamic> state) async {
    final file = await _getFile();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(state));
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  static Map<String, dynamic> _maybeReset(Map<String, dynamic> state) {
    if (state['date'] != _today()) {
      return {
        'date': _today(),
        'tap_used': 0,
        'export_used': 0,
      };
    }
    return state;
  }

  /// Ensure quota_state.json exists and is normalized for today
  static Future<QuotaStateResult> ensureState() async {
    final file = await _getFile();
    final existed = await file.exists();
    var state = await _loadState();
    state = _maybeReset(state);
    await _saveState(state);
    return QuotaStateResult(state: state, recreated: !existed);
  }

  static Future<QuotaCheckResult> checkAndConsumeTap({
    required String userId,
    String? userDisplayName,
  }) async {
    var state = await _loadState();
    state = _maybeReset(state);
    final used = (state['tap_used'] as int? ?? 0);
    final remaining = _tapLimitPerDay - used;
    final allowed = remaining > 0;
    final meta = {
      'type': 'tap_create',
      'used': used,
      'limit': _tapLimitPerDay,
      'remaining': remaining < 0 ? 0 : remaining,
    };

    await AuditService.logAction(
      tapCode: 'GLOBAL',
      userId: userId,
      userDisplayName: userDisplayName,
      action: AuditEventType.quotaCheck,
      eventType: AuditEventType.quotaCheck,
      target: 'tap_create',
      meta: meta,
    );

    if (!allowed) {
      await AuditService.logAction(
        tapCode: 'GLOBAL',
        userId: userId,
        userDisplayName: userDisplayName,
        action: AuditEventType.quotaBlocked,
        eventType: AuditEventType.quotaBlocked,
        target: 'tap_create',
        meta: meta,
      );
      return QuotaCheckResult(
        allowed: false,
        message: 'Hết quota tạo TAP miễn phí. Nâng cấp để tiếp tục.',
        remaining: 0,
        limit: _tapLimitPerDay,
        meta: meta,
      );
    }

    state['tap_used'] = used + 1;
    await _saveState(state);
    return QuotaCheckResult(
      allowed: true,
      message: 'Còn ${remaining - 1} lượt tạo TAP hôm nay.',
      remaining: remaining - 1,
      limit: _tapLimitPerDay,
      meta: meta,
    );
  }

  static Future<QuotaCheckResult> checkAndConsumeExport({
    required String userId,
    String? userDisplayName,
    String? tapCode,
  }) async {
    var state = await _loadState();
    state = _maybeReset(state);
    final used = (state['export_used'] as int? ?? 0);
    final remaining = _exportLimitPerDay - used;
    final allowed = remaining > 0;
    final meta = {
      'type': 'export',
      'tap_code': tapCode,
      'used': used,
      'limit': _exportLimitPerDay,
      'remaining': remaining < 0 ? 0 : remaining,
    };

    await AuditService.logAction(
      tapCode: tapCode ?? 'GLOBAL',
      userId: userId,
      userDisplayName: userDisplayName,
      action: AuditEventType.quotaCheck,
      eventType: AuditEventType.quotaCheck,
      target: 'export',
      meta: meta,
    );

    if (!allowed) {
      await AuditService.logAction(
        tapCode: tapCode ?? 'GLOBAL',
        userId: userId,
        userDisplayName: userDisplayName,
        action: AuditEventType.quotaBlocked,
        eventType: AuditEventType.quotaBlocked,
        target: 'export',
        meta: meta,
      );
      return QuotaCheckResult(
        allowed: false,
        message: 'Hết quota xuất file (ZIP/PDF). Nâng cấp để tiếp tục.',
        remaining: 0,
        limit: _exportLimitPerDay,
        meta: meta,
      );
    }

    state['export_used'] = used + 1;
    await _saveState(state);
    return QuotaCheckResult(
      allowed: true,
      message: 'Còn ${remaining - 1} lượt export hôm nay.',
      remaining: remaining - 1,
      limit: _exportLimitPerDay,
      meta: meta,
    );
  }

  static Future<Map<String, dynamic>> resetQuota({
    required String adminUserId,
    String? adminDisplayName,
  }) async {
    final state = {
      'date': _today(),
      'tap_used': 0,
      'export_used': 0,
    };
    await _saveState(state);
    await AuditService.logAction(
      tapCode: 'GLOBAL',
      userId: adminUserId,
      userDisplayName: adminDisplayName,
      action: AuditEventType.quotaReset,
      eventType: AuditEventType.quotaReset,
      target: 'quota',
      meta: state,
    );
    return state;
  }
}
