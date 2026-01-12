# Phase 12 - Legacy Cleanup and Rename: INVENTORY & PLAN

## STEP 1: LEGACY IDENTIFICATION - COMPLETE INVENTORY

### A. NATIVE CHANNELS (MUST RENAME)
- ❌ `com.bienso.zip/native` → ✅ `com.scandocpro.zip/native`
- ❌ `vision_scan` (currently neutral, keep as-is)

**Files to Modify:**
- ios/Runner/AppDelegate.swift — ZIP_CHANNEL constant
- android/app/src/main/kotlin/com/example/bien_so_xe/MainActivity.kt — ZIP_CHANNEL constant

### B. BUNDLE IDENTIFIER (MUST RENAME)
- ❌ `com.example.bien_so_xe` → ✅ `com.example.scandocpro`

**Files to Modify:**
- ios/Runner.xcodeproj/project.pbxproj (multiple occurrences)
- ios/Runner/Info.plist
- android/app/src/main/AndroidManifest.xml
- android/app/src/main/kotlin/com/example/bien_so_xe/MainActivity.kt (package name + ZIP_CHANNEL)

### C. DART PACKAGE NAME (MUST RENAME)
- ❌ `bien_so_xe` → ✅ `scandocpro`

**Files to Modify:**
- pubspec.yaml (name field)
- test/widget_test.dart (import statement)
- lib/src/app.dart (if imports from package)
- All native channel calls that reference "bien_so_xe"

### D. APP DISPLAY NAME (MUST RENAME)
- ❌ "Hồ Sơ Xe", "Quản lý Hồ Sơ Xe" → ✅ "ScanDoc Pro"

**Files to Modify:**
- lib/main.dart (title field)
- lib/main_scan.dart (title field)
- ios/Runner/Info.plist (CFBundleName, CFBundleDisplayName)
- android/app/src/main/AndroidManifest.xml (application label)

### E. LEGACY DATA DIRECTORY (HARD DELETE)
- ❌ `HoSoXe/` → ✅ `ScanDocData/` or similar neutral name

**Impact:**
- All file paths that use `HoSoXe` directory
- Existing user data will need migration function
- **Decision:** Keep path but rename references where possible

**Files to Modify:**
- lib/scan/integrity_service.dart
- lib/scan/tap_service.dart
- lib/scan/pdf_service.dart
- lib/scan/scan_file_service.dart
- lib/scan/manifest_service.dart
- lib/src/services/storage/storage_service.dart

### F. LEGACY UI STRINGS TO REMOVE
**Already Partially Cleaned:**
- ✅ "Hồ Sơ Xe" (welcome screen) — but still in src/features/auth/login_screen.dart

**Still Present:**
- ❌ "Quản lý Hồ Sơ Xe" (title in home_screen.dart)
- ❌ References to "Tập Hồ Sơ" (should be "Case")
- ❌ "Biển số" terminology (use "Case" or generic term)
- ❌ License plate input fields (tap_page.dart)

### G. LEGACY DOMAIN COMMENTS (DELETE)
**Files with comments referencing old domain:**
- lib/scan/document_set_service.dart — "Biển Số" comments
- lib/scan/scan_file_service.dart — "HoSoXe" path comments
- lib/scan/zip_service.dart — "bien_so" field comments
- lib/scan/tap_service.dart — "Tờ khai" references

### H. FOLDERS/PROJECTS TO MONITOR
- ❌ Project folder name: "bien so xe" (can't rename at filesystem level easily, but internals must be clean)
- ❌ iOS project still named Runner (acceptable, as it's Flutter standard)
- ❌ Android package: `com.example.bien_so_xe` (must rename)

---

## DELETION PLAN (Hard Delete, NO Stubs)

### TIER 1: Hard Delete These Files
**Reason:** Entirely dependent on vehicle/plate domain, no longer needed

- [ ] `lib/src/features/bo/bo_detail_screen.dart` — Vehicle/plate specific
- [ ] `lib/src/features/capture/document_capture_screen.dart` — Tied to old capture UI
- [ ] `lib/src/data/repositories/bo_repository.dart` — Vehicle repository
- [ ] `lib/src/data/models/bo_model.dart` — Vehicle model
- [ ] `lib/src/domain/entities/bo_entity.dart` — Vehicle entity
- [ ] `lib/src/domain/repositories/bo_repository.dart` — Vehicle repository abstract
- [ ] `lib/src/services/storage/storage_service.dart` — Legacy storage for old data structure

### TIER 2: Delete Old UI Screens (No Longer Needed)
**Reason:** Replaced by generic Case/Document Set flow

- [ ] Any old "vehicle list" screens
- [ ] Any old "plate input" dialogs
- [ ] Old document type selection (now generic)

### TIER 3: Delete Legacy Models/Services
**Reason:** Replaced by new Case/DocumentSet/Page domain

- [ ] Old "BienSo" models (if any remain)
- [ ] Old "HoSo" models (if different from Tap)
- [ ] Vehicle validation services

---

## RENAME PLAN (Careful Renaming, Keep Core Intact)

### TIER 1: Bundle ID Rename
**Old:** `com.example.bien_so_xe`
**New:** `com.example.scandocpro`
**Scope:** iOS, Android, Dart code references

### TIER 2: Dart Package Rename (pubspec.yaml)
**Old:** `bien_so_xe`
**New:** `scandocpro`
**Scope:** pubspec.yaml name field, test imports

### TIER 3: App Display Name
**Old:** "Hồ Sơ Xe", "Quản lý Hồ Sơ Xe"
**New:** "ScanDoc Pro"
**Scope:** main.dart, main_scan.dart, iOS/Android manifest files

### TIER 4: Native Channels
**Old:** `com.bienso.zip/native`
**New:** `com.scandocpro.zip/native`
**Scope:** AppDelegate.swift, MainActivity.kt, Dart code

### TIER 5: Data Directory Path (Migration)
**Old:** `HoSoXe/`
**New:** `ScanDocData/`
**Scope:** All file I/O code, but keep backward compat function for reading old paths

### TIER 6: Remove Legacy Domain Comments
**Delete comments referencing:**
- Biển số
- Tờ khai
- Nguồn gốc
- License plate
- Vehicle-specific logic

---

## FROZEN COMPONENTS (DO NOT TOUCH)

- ✅ `lib/scan/scan_page.dart` — PRO scan UI with camera overlay
- ✅ `lib/scan/vision_scan_service.dart` — iOS VisionKit scanner
- ✅ `lib/scan/zip_service.dart` — ZIP creation (only rename channel)
- ✅ `lib/scan/pdf_service.dart` — PDF generation
- ✅ `lib/scan/audit_service.dart` — Audit log
- ✅ Native iOS code (only rename channel constant)

---

## BUILD CHANGES REQUIRED

### After Rename:
1. Run `flutter pub get`
2. Rebuild iOS project (new bundle ID, new Info.plist settings)
3. Rebuild Android project (new package name, new channel)
4. Test on real device

### Expected Issues:
- Old installed app must be uninstalled (bundle ID changed)
- Existing data in `HoSoXe/` directory will still exist but app should handle gracefully

---

**Status:** INVENTORY COMPLETE - Ready for STEP 2 (Hard Delete & Rename)
