import 'dart:io';
import 'package:flutter/services.dart';

/// VisionKit Scanner Service (iOS native only)
/// ✅ Multi-page support - returns List<String> temp file paths
/// ✅ Không MLKit, không plugin trung gian
class VisionScanService {
  static const channel = MethodChannel('vision_scan');

  /// Scan tài liệu - hỗ trợ multi-page
  /// Returns: List<String>? - đường dẫn temp files (null nếu user cancel)
  /// VisionKit tự xin quyền camera trên lần đầu
  static Future<List<String>?> scanDocument() async {
    try {
      print('📱 Calling iOS VisionKit...');
      
      // Gọi native iOS method - nhận List<String>
      final List<dynamic> imagePaths = 
          await channel.invokeMethod<List<dynamic>>('startScan') as List<dynamic>? ?? [];

      if (imagePaths.isEmpty) {
        print('❌ Scan cancelled by user');
        return null;
      }

      final List<String> paths = imagePaths.map((p) => p.toString()).toList();
      print('✓ Received ${paths.length} page(s)');
      
      // Verify all files exist
      for (var path in paths) {
        final file = File(path);
        if (!await file.exists()) {
          print('❌ File not found: $path');
          return null;
        }
        final sizeBytes = await file.length();
        print('📦 Page: ${path.split('/').last} (${sizeBytes} bytes)');
      }

      return paths;
    } on PlatformException catch (e) {
      print('❌ Platform error: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }
}
