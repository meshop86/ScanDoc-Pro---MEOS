import 'dart:io';

/// Kết quả scan tài liệu
class ScanResult {
  final File imageFile;
  final DateTime timestamp;

  ScanResult({
    required this.imageFile,
    required this.timestamp,
  });

  String get path => imageFile.path;
  int get sizeBytes => imageFile.lengthSync();
}
