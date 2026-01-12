# MLKit Document Scanner Module

## ⚠️ CRITICAL NOTES

### Platform Requirements
- **iOS**: ≥ 15.5 (already updated in Podfile)
- **Android**: ≥ 5.0 (API 21)
- **Device Only**: ❌ KHÔNG test simulator

### File Structure
```
lib/
├─ scan/
│   ├─ scan_service.dart     # MLKit wrapper
│   ├─ scan_page.dart        # UI test
│   └─ scan_result.dart      # Model
└─ main_scan.dart            # Test app
```

## Features Implemented

✅ MLKit DocumentScanner integration
✅ Auto detect 4 corners
✅ Auto crop + perspective correction
✅ Auto image enhancement (BW/sharpen)
✅ Preview → Retake → Save flow
✅ Save JPG to local storage (getApplicationDocumentsDirectory)
✅ Return File object (NO base64)
✅ Offline 100%

## Usage

### Run Test App
```bash
# On device ONLY
flutter run lib/main_scan.dart -d 00008120-00043D3E14A0C01E
```

### In Your Code
```dart
import 'lib/scan/scan_service.dart';

final scanService = ScanService();
await scanService.init();

final result = await scanService.scanDocument();
if (result != null) {
  final imageFile = result.imageFile;  // File object
  print('Saved: ${result.path}');
}
```

### ScanResult Model
```dart
class ScanResult {
  final File imageFile;        // ✅ File object (NOT base64)
  final DateTime timestamp;
  
  String get path => imageFile.path;
  int get sizeBytes => imageFile.lengthSync();
}
```

## MLKit Workflow

1. User taps "Chụp & Scan"
2. MLKit opens camera UI
3. Auto detect 4 corners
4. Auto crop + perspective transform
5. Auto enhance (BW/sharpen/denoise)
6. Show preview
7. User: Retake OR Save
8. Save → Copy to Documents → Return File

## Permissions (Already Added)

✅ NSCameraUsageDescription
✅ NSPhotoLibraryAddUsageDescription

## File Output

- Location: `{getApplicationDocumentsDirectory()}/scan_*.jpg`
- Format: JPEG (MLKit default)
- Quality: 80 (MLKit default)
- Resolution: ~2-4MP (auto-scaled)

## Troubleshooting

### "Plugin requires iOS 15.5+"
→ Already fixed in Podfile

### "Camera permission denied"
→ Grant permission in Settings → App → Camera

### "MLKit not detecting corners"
→ Ensure:
  - Good lighting
  - Document has clear edges
  - Document mostly fills frame

### "Simulator crash"
→ Expected! Only test on real device

## Next Steps (When Requested)
- ZIP module
- Share integration
- Gallery import
