# MLKit Document Scanner - Usage Guide

## ⚠️ IMPORTANT: CHỈ CHẠY TRÊN THIẾT BỊ THẬT
MLKit Document Scanner KHÔNG hoạt động trên simulator.

## 1. Test độc lập

```bash
# Run test file
flutter run test_mlkit_scan.dart -d 00008120-00043D3E14A0C01E
```

## 2. Integrate vào app

```dart
import 'package:flutter/material.dart';
import 'src/services/scan/scan_service.dart';
import 'dart:io';

// Trong widget
final _scanService = ScanService();

Future<void> _scanDocument() async {
  final file = await _scanService.scanDocument();
  if (file != null) {
    // file là ảnh đã crop + perspective corrected
    // Dùng ngay hoặc copy vào storage
  }
}

@override
void dispose() {
  _scanService.dispose();
  super.dispose();
}
```

## 3. Luồng MLKit

```
Nhấn Scan
 ↓
MLKit mở camera built-in
 ↓
Tự động detect 4 góc
 ↓
Tự động crop + perspective transform
 ↓
Tự động enhance (BW/sharpen)
 ↓
Trả về File ảnh JPG
```

## 4. Share sau scan

```dart
import 'package:share_plus/share_plus.dart';

final scannedFile = await _scanService.scanDocument();
if (scannedFile != null) {
  await Share.shareXFiles([XFile(scannedFile.path)]);
}
```

## 5. Native ZIP (đã có sẵn)

```dart
import 'src/services/zip/native_zip_service.dart';

final zipService = NativeZipService();
await zipService.zipFolder(
  sourcePath: '/path/to/folder',
  outputPath: '/path/to/output.zip',
);

// Share ZIP
await Share.shareXFiles([XFile('/path/to/output.zip')]);
```

## 6. Troubleshooting

### Share không hoạt động?
- Đã thêm `NSPhotoLibraryAddUsageDescription` trong Info.plist ✓
- Restart app sau khi thay đổi permissions
- Kiểm tra logs: `=== SHARE CLICKED ===`

### MLKit crash?
- Chỉ test trên thiết bị thật
- iOS >= 13.0
- Permissions camera đã cấp

### Không detect góc?
- MLKit tự động detect, không cần config thêm
- Đảm bảo ánh sáng đủ khi scan
- Document phải có viền rõ ràng
