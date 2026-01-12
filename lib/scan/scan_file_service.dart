import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'tap_service.dart';
import 'tap_status.dart';

/// File management service cho scanned documents
/// ✅ Multi-page support - lưu nhiều trang với naming: to_khai_p1.jpg, to_khai_p2.jpg, ...
/// ✅ TAP support - lưu theo cấu trúc: HoSoXe/<tapCode>/<bien_so>/<docType>_p<n>.jpg
class ScanFileService {
  static const String _hosoFolder = 'HoSoXe';

  /// Lấy đường dẫn thư mục của 1 hồ sơ
  /// Path: <documents>/HoSoXe/<tapCode>/<bien_so>/
  static Future<Directory> getHosoDirectory(String bienSo, {String? tapCode}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    
    final String hosoPath;
    if (tapCode != null) {
      hosoPath = '${docsDir.path}/$_hosoFolder/$tapCode/$bienSo';
    } else {
      hosoPath = '${docsDir.path}/$_hosoFolder/$bienSo';
    }
    
    final hosoDir = Directory(hosoPath);

    if (!await hosoDir.exists()) {
      await hosoDir.create(recursive: true);
      print('✓ Created: ${hosoDir.path}');
    }

    return hosoDir;
  }

  /// Lấy đường dẫn file ảnh theo loại giấy tờ + trang
  /// NEW FORMAT: <docType>_<bienSo>_p<n>.jpg
  /// VD: to_khai_14Bx-4524_p1.jpg
  static Future<String> getDocumentFilePath(
    String bienSo,
    String docType,
    int pageNumber, {
    String? tapCode,
  }) async {
    final hosoDir = await getHosoDirectory(bienSo, tapCode: tapCode);
    return '${hosoDir.path}/${docType}_${bienSo}_p${pageNumber}.jpg';
  }

  /// Kiểm tra file ảnh đã tồn tại chưa
  static Future<bool> documentPageExists(
    String bienSo,
    String docType,
    int pageNumber, {
    String? tapCode,
  }) async {
    final filePath = await getDocumentFilePath(bienSo, docType, pageNumber, tapCode: tapCode);
    return await File(filePath).exists();
  }

  /// Lưu nhiều file ảnh scan (multi-page)
  /// tempFilePaths: danh sách đường dẫn temp từ VisionKit
  /// Returns: List<File> đã lưu vào thư mục cuối cùng
  static Future<List<File>> saveScannedFiles({
    required List<String> tempFilePaths,
    required String bienSo,
    required String docType,
    String? tapCode,
  }) async {
    if (tapCode != null) {
      final status = await TapService.getTapStatus(tapCode);
      if (!status.isOpen) {
        throw Exception('TAP không ở trạng thái OPEN, không thể lưu ảnh');
      }
    }
    final savedFiles = <File>[];

    for (int i = 0; i < tempFilePaths.length; i++) {
      final pageNumber = i + 1;
      final tempFile = File(tempFilePaths[i]);

      if (!await tempFile.exists()) {
        print('❌ Temp file not found: $tempFilePaths[i]');
        continue;
      }

      // Lấy đường dẫn file cuối cùng
      final filePath = await getDocumentFilePath(bienSo, docType, pageNumber, tapCode: tapCode);
      final targetFile = File(filePath);

      // Xóa file cũ nếu tồn tại
      if (await targetFile.exists()) {
        await targetFile.delete();
        print('🗑️ Deleted old: ${docType}_${bienSo}_p${pageNumber}.jpg');
      }

      // Copy file từ vị trí tạm sang vị trí cuối cùng
      final savedFile = await tempFile.copy(filePath);
      savedFiles.add(savedFile);
      print('💾 Saved: ${docType}_${bienSo}_p${pageNumber}.jpg');
    }

    return savedFiles;
  }

  /// Lấy File object của một trang nếu tồn tại
  static Future<File?> getDocumentPage(
    String bienSo,
    String docType,
    int pageNumber, {
    String? tapCode,
  }) async {
    final filePath = await getDocumentFilePath(bienSo, docType, pageNumber, tapCode: tapCode);
    final file = File(filePath);

    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Lấy tất cả các trang của 1 loại giấy tờ
  /// Returns: List<File> sắp xếp theo trang (p1, p2, p3...)
  static Future<List<File>> getDocumentPages(
    String bienSo,
    String docType, {
    String? tapCode,
  }) async {
    final hosoDir = await getHosoDirectory(bienSo, tapCode: tapCode);
    // Match: <docType>_<bienSo>_p<n>.jpg
    final pattern = RegExp('^${RegExp.escape(docType)}_${RegExp.escape(bienSo)}_p(\\d+)\\.jpg\$');

    final allFiles = hosoDir.listSync().whereType<File>().toList();
    
    final matchedFiles = allFiles
        .where((f) => pattern.hasMatch(f.path.split('/').last))
        .toList();

    // Sort by page number
    matchedFiles.sort((a, b) {
      final aNum = int.tryParse(
        pattern.firstMatch(a.path.split('/').last)?.group(1) ?? '0',
      ) ?? 0;
      final bNum = int.tryParse(
        pattern.firstMatch(b.path.split('/').last)?.group(1) ?? '0',
      ) ?? 0;
      return aNum.compareTo(bNum);
    });

    return matchedFiles;
  }

  /// Xóa 1 trang của document
  static Future<void> deleteDocumentPage(
    String bienSo,
    String docType,
    int pageNumber, {
    String? tapCode,
  }) async {
    if (tapCode != null) {
      final status = await TapService.getTapStatus(tapCode);
      if (!status.isOpen) {
        throw Exception('TAP không ở trạng thái OPEN, không thể xoá ảnh');
      }
    }
    final filePath = await getDocumentFilePath(bienSo, docType, pageNumber, tapCode: tapCode);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
      print('🗑️ Deleted: ${docType}_${bienSo}_p${pageNumber}.jpg');
    }
  }

  /// Xóa toàn bộ 1 loại giấy tờ (tất cả các trang)
  static Future<void> deleteDocument(String bienSo, String docType, {String? tapCode}) async {
    if (tapCode != null) {
      final status = await TapService.getTapStatus(tapCode);
      if (!status.isOpen) {
        throw Exception('TAP không ở trạng thái OPEN, không thể xoá giấy tờ');
      }
    }
    final pages = await getDocumentPages(bienSo, docType, tapCode: tapCode);
    for (var file in pages) {
      await file.delete();
    }
    print('🗑️ Deleted all pages of: $docType');
  }

  /// Xóa toàn bộ hồ sơ
  static Future<void> deleteHoso(String bienSo, {String? tapCode}) async {
    if (tapCode != null) {
      final status = await TapService.getTapStatus(tapCode);
      if (!status.isOpen) {
        throw Exception('TAP không ở trạng thái OPEN, không thể xoá hồ sơ');
      }
    }
    final hosoDir = await getHosoDirectory(bienSo, tapCode: tapCode);

    if (await hosoDir.exists()) {
      await hosoDir.delete(recursive: true);
      print('🗑️ Deleted hoso: ${hosoDir.path}');
    }
  }
}
