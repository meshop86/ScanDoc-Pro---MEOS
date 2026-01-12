import 'dart:io';

/// Model kết quả scan
class ScanResult {
  final File imageFile;
  final int width;
  final int height;
  final DateTime timestamp;

  ScanResult({
    required this.imageFile,
    required this.width,
    required this.height,
    required this.timestamp,
  });

  String get path => imageFile.path;
  int get sizeBytes => imageFile.lengthSync();
}
