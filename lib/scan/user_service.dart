import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert' as conv show utf8;

/// Quản lý trạng thái user/offline admin unlock.
class UserService {
  static const _stateFile = 'user_state.json';
  static const _currentUserFile = 'current_user.json';
  // PIN bí mật cho admin mode (offline). Có thể đổi khi build.
  static const String _adminPin = '8642';

  static Future<File> _getStateFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$_stateFile');
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode({'admin_unlocked': false}));
    }
    return file;
  }

  static Future<bool> isAdminUnlocked() async {
    try {
      final file = await _getStateFile();
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data['admin_unlocked'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> unlockWithPin(String pin) async {
    final matched = pin == _adminPin;
    final file = await _getStateFile();
    await file.writeAsString(jsonEncode({'admin_unlocked': matched}));
    return matched;
  }

  static Future<void> resetAdmin() async {
    final file = await _getStateFile();
    await file.writeAsString(jsonEncode({'admin_unlocked': false}));
  }

  // --- Login/Logout (offline) ---
  static Future<File> _getCurrentUserFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/$_currentUserFile');
  }

  static Future<void> loginOffline(String displayName) async {
    final userId = _generateUserId(displayName);
    final file = await _getCurrentUserFile();
    await file.writeAsString(jsonEncode({
      'user_id': userId,
      'display_name': displayName,
    }));
  }

  static Future<Map<String, String>?> getCurrentUser() async {
    try {
      final file = await _getCurrentUserFile();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return {
        'user_id': data['user_id']?.toString() ?? '',
        'display_name': data['display_name']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> logoutOffline() async {
    final file = await _getCurrentUserFile();
    if (await file.exists()) await file.delete();
  }

  static String _generateUserId(String displayName) {
    final hash = md5.convert(conv.utf8.encode(displayName + DateTime.now().millisecondsSinceEpoch.toString()));
    return 'user_${hash.toString().substring(0, 8)}';
  }
}
