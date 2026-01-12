import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'tap_status.dart';

/// Tap (Tập hồ sơ) service
/// Quản lý nhiều bộ hồ sơ trong 1 Tập
class TapService {
  static const _hosoRoot = 'HoSoXe';
  static const _tapStatusFile = 'tap_status.json';

  static Future<File> _getStatusFile(String tapCode) async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/$_hosoRoot/$tapCode/$_tapStatusFile');
  }

  static Future<TapStatus> getTapStatus(String tapCode) async {
    try {
      final file = await _getStatusFile(tapCode);
      if (!await file.exists()) return TapStatus.open;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return TapStatusX.from(data['status']?.toString());
    } catch (_) {
      return TapStatus.open;
    }
  }

  static Future<void> setTapStatus(String tapCode, TapStatus status) async {
    final file = await _getStatusFile(tapCode);
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode({'status': status.value}));
  }

  static Future<void> _ensureUnlocked(String tapCode) async {
    final status = await getTapStatus(tapCode);
    if (status.isLocked) {
      throw Exception('TAP đang bị khóa (LOCKED)');
    }
  }
  static Future<void> _ensureOpen(String tapCode) async {
    final status = await getTapStatus(tapCode);
    if (!status.isOpen) {
      throw Exception('TAP không ở trạng thái OPEN');
    }
  }

  /// Tạo Tập mới với tapCode (vd: TAP_001)
  /// Returns: tap directory
  static Future<Directory> createTap(String tapCode) async {
    final docs = await getApplicationDocumentsDirectory();
    final tapDir = Directory('${docs.path}/$_hosoRoot/$tapCode');
    if (!await tapDir.exists()) {
      await tapDir.create(recursive: true);
      print('✓ Created TAP: ${tapDir.path}');
    }
    await setTapStatus(tapCode, TapStatus.open);
    return tapDir;
  }

  /// Lấy danh sách tất cả TAP
  static Future<List<String>> listTaps() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/$_hosoRoot');
    if (!await root.exists()) return [];

    final taps = root
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.split('/').last.startsWith('TAP_'))
        .map((d) => d.path.split('/').last)
        .toList();
    
    return taps;
  }

  /// Lấy danh sách bộ hồ sơ (biển số) trong 1 TAP
  static Future<List<String>> listBoHoSo(String tapCode) async {
    final docs = await getApplicationDocumentsDirectory();
    final tapDir = Directory('${docs.path}/$_hosoRoot/$tapCode');
    if (!await tapDir.exists()) return [];

    final bienSoList = tapDir
        .listSync()
        .whereType<Directory>()
        .where((d) => !d.path.endsWith('tap_manifest.json'))
        .map((d) => d.path.split('/').last)
        .toList();

    return bienSoList;
  }

  /// Thêm bộ hồ sơ (biển số) vào TAP
  /// Returns: bo ho so directory
  static Future<Directory> addBoHoSo(String tapCode, String bienSo) async {
    await _ensureOpen(tapCode);
    final docs = await getApplicationDocumentsDirectory();
    final boDir = Directory('${docs.path}/$_hosoRoot/$tapCode/$bienSo');
    if (!await boDir.exists()) {
      await boDir.create(recursive: true);
      print('✓ Added bộ hồ sơ: $bienSo to TAP $tapCode');
    }
    return boDir;
  }

  /// Xoá bộ hồ sơ khỏi TAP
  static Future<void> deleteBoHoSo(String tapCode, String bienSo) async {
    await _ensureOpen(tapCode);
    final docs = await getApplicationDocumentsDirectory();
    final boDir = Directory('${docs.path}/$_hosoRoot/$tapCode/$bienSo');
    if (await boDir.exists()) {
      await boDir.delete(recursive: true);
      print('🗑️ Deleted: $bienSo from TAP $tapCode');
    }
  }

  /// Xoá toàn bộ TAP
  static Future<void> deleteTap(String tapCode) async {
    final docs = await getApplicationDocumentsDirectory();
    final tapDir = Directory('${docs.path}/$_hosoRoot/$tapCode');
    if (await tapDir.exists()) {
      await tapDir.delete(recursive: true);
      print('🗑️ Deleted TAP: $tapCode');
    }
  }

  /// Check bộ hồ sơ có đủ giấy tờ bắt buộc không
  /// Returns: true nếu có ít nhất to_khai (linh hoạt, không bắt buộc nguon_goc)
  static Future<bool> isBoComplete(String tapCode, String bienSo) async {
    final docs = await getApplicationDocumentsDirectory();
    final boDir = Directory('${docs.path}/$_hosoRoot/$tapCode/$bienSo');
    if (!await boDir.exists()) return false;

    final files = boDir
      .listSync()
      .whereType<File>()
      .map((f) => f.path.split('/').last.toLowerCase())
      .toList();

    // Chỉ bắt buộc Tờ khai, các giấy khác tùy chọn
    final prefix = 'to_khai_${bienSo.toLowerCase()}_p';
    final hasToKhai = files.any((f) => f.startsWith(prefix) && f.endsWith('.jpg'));
    return hasToKhai;
  }

  /// Generate tap code mới (TAP_###)
  static Future<String> generateTapCode() async {
    final taps = await listTaps();
    if (taps.isEmpty) return 'TAP_001';

    // Tìm số lớn nhất
    final nums = taps
        .map((t) => int.tryParse(t.replaceAll('TAP_', '')) ?? 0)
        .toList()..sort();
    
    final nextNum = (nums.last) + 1;
    return 'TAP_${nextNum.toString().padLeft(3, '0')}';
  }

  /// Rename bộ hồ sơ (atomic operation)
  /// oldBienSo: biển số cũ
  /// newBienSo: biển số mới
  /// Returns: true nếu thành công
  static Future<bool> renameBoHoSo(String tapCode, String oldBienSo, String newBienSo) async {
    await _ensureOpen(tapCode);
    final docs = await getApplicationDocumentsDirectory();
    final oldDir = Directory('${docs.path}/$_hosoRoot/$tapCode/$oldBienSo');
    final newDir = Directory('${docs.path}/$_hosoRoot/$tapCode/$newBienSo');

    if (!await oldDir.exists()) {
      throw Exception('Bộ hồ sơ không tồn tại');
    }

    if (await newDir.exists()) {
      throw Exception('Biển số mới đã tồn tại');
    }

    try {
      // Atomic rename directory
      await oldDir.rename(newDir.path);
      print('✓ Renamed: $oldBienSo → $newBienSo');
      return true;
    } catch (e) {
      print('❌ Rename failed: $e');
      rethrow;
    }
  }

  /// Rename TAP (atomic operation)
  static Future<void> renameTap(String oldCode, String newCode) async {
    final docs = await getApplicationDocumentsDirectory();
    final oldDir = Directory('${docs.path}/$_hosoRoot/$oldCode');
    final newDir = Directory('${docs.path}/$_hosoRoot/$newCode');

    if (!await oldDir.exists()) {
      throw Exception('TAP không tồn tại');
    }

    if (await newDir.exists()) {
      throw Exception('Tên TAP mới đã tồn tại');
    }

    try {
      await oldDir.rename(newDir.path);
      print('✓ Renamed TAP: $oldCode → $newCode');
    } catch (e) {
      print('❌ Rename TAP failed: $e');
      rethrow;
    }
  }
}
