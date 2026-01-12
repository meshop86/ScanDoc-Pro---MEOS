import 'dart:io';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

/// MLKit Document Scanner Service
/// ⚠️ CHỈ CHẠY TRÊN THIẾT BỊ THẬT (không chạy simulator)
class ScanService {
  DocumentScanner? _scanner;

  /// Khởi tạo scanner với config
  Future<void> init() async {
    final options = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.full, // full mode có UI built-in
      pageLimit: 1, // 1 trang
      isGalleryImport: false,
    );
    _scanner = DocumentScanner(options: options);
  }

  /// Scan tài liệu với MLKit
  /// Returns: File ảnh đã crop + perspective corrected
  Future<File?> scanDocument() async {
    if (_scanner == null) await init();

    try {
      final result = await _scanner!.scanDocument();
      
      if (result == null) return null;
      
      // MLKit trả về ảnh đã xử lý (auto crop, perspective, enhance)
      if (result.images.isNotEmpty) {
        final imagePath = result.images.first;
        return File(imagePath);
      }
      
      return null;
    } catch (e) {
      print('❌ MLKit scan error: $e');
      return null;
    }
  }

  void dispose() {
    _scanner?.close();
  }
}
