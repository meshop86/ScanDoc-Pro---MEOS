import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// ProEntitlementService
/// Local-only entitlement flag for PRO tier (no backend dependency)
class ProEntitlementService {
  static const String _fileName = 'pro_entitlement.json';

  /// Check if PRO is active locally
  static Future<bool> isProActive() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/$_fileName');
      if (!await file.exists()) return false;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data['active'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Activate PRO locally
  static Future<void> activate() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$_fileName');
    await file.writeAsString(jsonEncode({
      'active': true,
      'activated_at': DateTime.now().toIso8601String(),
    }));
  }

  /// Deactivate PRO locally
  static Future<void> deactivate() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$_fileName');
    if (await file.exists()) {
      await file.writeAsString(jsonEncode({
        'active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }));
    }
  }
}
