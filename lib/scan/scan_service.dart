import 'dart:io';
// import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'scan_result.dart';

/// MLKit Document Scanner Service - DEPRECATED
/// ⚠️ NOT USED - VisionScanService is the active implementation
/// This file exists for backwards compatibility only
class ScanService {
  // DocumentScanner? _scanner;

  /// Init MLKit Scanner - STUB
  Future<void> init() async {
    // Stub - VisionScanService is used instead
  }

  /// Scan tài liệu - STUB
  /// Use VisionScanService.scanDocument() instead
  Future<ScanResult?> scanDocument() async {
    throw UnimplementedError('Use VisionScanService instead');
  }

  void dispose() {
    // Stub
  }
}
