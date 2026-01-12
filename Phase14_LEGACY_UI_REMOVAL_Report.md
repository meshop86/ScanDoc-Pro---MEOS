# Phase 14 – Legacy UI Complete Removal Report

**Date:** 8 Jan 2026  
**Trigger:** User request "Vẫn liên quan tới giao diện biển số xe cũ, hãy loại bỏ hoàn toàn sang form mới"  
**Goal:** Eliminate ALL legacy vehicle UI ("Biển số", "Tờ khai") and switch to Phase 13+ architecture

---

## 🎯 ROOT CAUSE IDENTIFIED

**Problem:** App was running **OLD scan module** (`lib/scan/tap_manage_page.dart`) instead of Phase 13 architecture.

**Evidence:**
- `lib/main.dart` imported `scan/login_page.dart`, `scan/tap_manage_page.dart`
- App entry point was `TapManagePage()` → Old UI with vehicle terminology
- Phase 13 routing (GoRouter + Riverpod) was defined but **never activated**

---

## 📝 FILES CHANGED

### 1. **DELETED: `lib/main.dart` (Legacy)**
**Before:**
```dart
import 'scan/login_page.dart';
import 'scan/tap_manage_page.dart';
// Old MaterialApp with TapManagePage entry
```

**Why:** This was the OLD entry point using legacy scan module.

### 2. **DELETED: `lib/main_scan.dart` (Legacy)**
Same as main.dart - duplicate legacy entry point.

### 3. **CREATED: `lib/main.dart` (NEW - Phase 13+)**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/routing/app_router.dart';
import 'src/data/database/database.dart';
import 'src/services/migration/migration_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(migrationProvider);
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'ScanDoc Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

**Impact:** 
- ✅ Now uses Riverpod + GoRouter architecture
- ✅ Triggers migration service on startup
- ✅ Routes to Phase 13 screens (home_screen_new.dart, case_detail_screen.dart)
- ❌ **NO MORE** legacy scan module screens

---

### 4. **FIXED: `lib/src/services/migration/migration_service.dart`**
**Issue:** Import paths were wrong (relative paths from wrong location)

**Before:**
```dart
import '../data/database/database.dart';
import '../domain/models.dart';
```

**After:**
```dart
import '../../data/database/database.dart';
import '../../domain/models.dart';
```

**Why:** File is in `lib/src/services/migration/`, needs to go up 2 levels to reach `lib/src/data/`.

---

### 5. **FIXED: `lib/src/features/home/case_providers.dart`**
**Issue:** Same import path error

**Before:**
```dart
import '../data/database/database.dart' as db;
```

**After:**
```dart
import '../../data/database/database.dart' as db;
```

---

### 6. **FIXED: `lib/src/features/home/home_screen_new.dart`**
**Issue:** Type mismatch - used `models.Case` but providers return `db.Case`

**Before:**
```dart
import '../../domain/models.dart';

class _CaseCard extends ConsumerWidget {
  final Case caseData; // models.Case
  
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = caseData.isCompleted ? Colors.green : Colors.blue;
    final statusText = caseData.isCompleted ? 'Completed' : 'Active';
    subtitle: Text('${caseData.totalPageCount} pages · $statusText'),
  }
}
```

**After:**
```dart
import '../../data/database/database.dart' as db;

class _CaseCard extends ConsumerWidget {
  final db.Case caseData; // database type
  
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = caseData.status == 'completed';
    final statusColor = isCompleted ? Colors.green : Colors.blue;
    final statusText = isCompleted ? 'Completed' : 'Active';
    
    final pagesAsync = ref.watch(pagesByCaseProvider(caseData.id));
    subtitle: pagesAsync.when(
      data: (pages) => Text('${pages.length} pages · $statusText'),
      loading: () => const Text('Loading...'),
      error: (_, __) => Text(statusText),
    ),
  }
}
```

**Why:** 
- Database types don't have `isCompleted` or `totalPageCount` (domain model properties)
- Must use `status` column and fetch pages separately

---

### 7. **FIXED: `lib/src/features/scan/quick_scan_screen.dart`**
**Issue 1:** Type mismatch - used `models.Case` but should use `db.Case`

**Before:**
```dart
models.Case? qscanCase;
qscanCase = allCases.cast<models.Case>().firstWhereOrNull((c) => c.name == qscanCaseName);

final newCase = models.Case(
  name: qscanCaseName,
  description: 'Quick Scan documents',
  ownerUserId: 'default',
);
```

**After:**
```dart
db.Case? qscanCase;
try {
  qscanCase = allCases.firstWhere((c) => c.name == qscanCaseName);
} catch (_) {
  qscanCase = null;
}

if (qscanCase == null) {
  final caseId = 'qscan_${DateTime.now().millisecondsSinceEpoch}';
  await database.createCase(
    db.CasesCompanion(
      id: drift.Value(caseId),
      name: const drift.Value(qscanCaseName),
      description: const drift.Value('Quick Scan documents'),
      status: const drift.Value('active'),
      createdAt: drift.Value(DateTime.now()),
      ownerUserId: const drift.Value('default'),
    ),
  );
  qscanCase = (await database.getAllCases()).firstWhere((c) => c.id == caseId);
}
```

**Issue 2:** Missing required fields in `PagesCompanion`

**Before:**
```dart
await database.createPage(
  db.PagesCompanion(
    id: drift.Value(pageId),
    caseId: drift.Value(qscanCase.id),
    name: drift.Value('Page $pageNumber'),
    imagePath: drift.Value(imagePath),
    createdAt: drift.Value(DateTime.now()),
  ),
);
```

**After:**
```dart
final now = DateTime.now();
await database.createPage(
  db.PagesCompanion(
    id: drift.Value(pageId),
    caseId: drift.Value(qscanCase.id),
    name: drift.Value('Page $pageNumber'),
    imagePath: drift.Value(imagePath),
    status: const drift.Value('active'),      // ✅ ADDED
    createdAt: drift.Value(now),
    updatedAt: drift.Value(now),              // ✅ ADDED
  ),
);
```

**Why:** Database schema requires `status` and `updatedAt` (NOT NULL columns).

---

### 8. **RAN: `dart run build_runner build`**
Generated Drift database code:
- `lib/src/data/database/database.g.dart`
- All table companions and type definitions

**Why:** After changing imports, needed to regenerate to resolve types.

---

## 🔄 EXECUTION TIMELINE

1. **User reported:** Still seeing "Biển số xe" UI
2. **Root cause found:** `main.dart` using old scan module
3. **Deleted:** `main.dart`, `main_scan.dart` (legacy)
4. **Created:** New `main.dart` with Phase 13 architecture
5. **Fixed import paths:** migration_service, case_providers (2 levels up)
6. **Fixed type conflicts:** home_screen_new (models → db types)
7. **Fixed type conflicts:** quick_scan_screen (models → db, added status/updatedAt)
8. **Regenerated:** Database code with build_runner
9. **Build failed:** Import errors → **Fixed**
10. **Build failed:** Type errors → **Fixed**
11. **Build succeeded:** 82.9s, installed to iPhone
12. **Current status:** App launches but **black screen after scan Done**

---

## ⚠️ CURRENT ISSUE: Black Screen After "Done"

**Symptoms:**
- Scan works (2 pages scanned)
- Error WAS showing (status/updatedAt missing) - **NOW FIXED**
- Tap "Done" → Black screen, no navigation

**Possible Causes:**

### A. Navigation Logic Issue
Quick scan completion should:
1. Save pages to database ✅
2. Navigate back to Home ❓

Check `quick_scan_screen.dart` navigation after save:

```dart
// After saving pages
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('✓ Saved ${_scannedPages.length} pages to QScan'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ),
  );
  
  // Refresh case list
  ref.invalidate(caseListProvider);
  
  // Navigate back to Home
  context.go(Routes.home);  // ❓ IS THIS LINE PRESENT?
}
```

### B. Provider/Database Error
After save, if there's a runtime error:
- Case list provider fails to load
- Home screen crashes silently
- Black screen appears

### C. Route Configuration
If `Routes.home` is not defined or misconfigured in `app_router.dart`:
- Navigation fails silently
- Black screen

---

## 🔍 DIAGNOSIS NEEDED

**Check 1: Does Done button navigate?**
```dart
// In quick_scan_screen.dart, after saving
context.go(Routes.home);
```

**Check 2: Check Home screen logs**
- Does HomeScreen build() get called?
- Do providers load?
- Any runtime errors?

**Check 3: Check app_router.dart**
- Is `Routes.home` → `'/'` correctly mapped?
- Does StatefulShellRoute work?

---

## 📊 SUMMARY OF CHANGES

| File | Action | Reason | Impact |
|------|--------|--------|--------|
| `lib/main.dart` | Replaced | Switch to Phase 13 architecture | ✅ No more legacy UI |
| `lib/main_scan.dart` | Deleted | Duplicate legacy entry | ✅ Clean |
| `migration_service.dart` | Fixed imports | Wrong relative paths | ✅ Compiles |
| `case_providers.dart` | Fixed imports | Wrong relative paths | ✅ Compiles |
| `home_screen_new.dart` | Type fix | models.Case → db.Case | ✅ Compiles |
| `quick_scan_screen.dart` | Type fix + fields | models → db, add status/updatedAt | ✅ Compiles, saves work |
| Database code | Regenerated | build_runner | ✅ Types available |

---

## ✅ VERIFIED WORKING

- ✅ App launches (no crash)
- ✅ Scan tab accessible
- ✅ VisionKit camera opens
- ✅ 2 pages scanned successfully
- ✅ Database save (no error banner after fix)

## ❌ NOT WORKING

- ❌ Navigation after Done → Black screen
- ❌ Cannot access Home after scan

---

## 🚨 NEXT STEPS

1. **Check `quick_scan_screen.dart` line ~150** - Does it call `context.go(Routes.home)` after save?
2. **Add debug logs** - Print when Done is tapped, when navigation happens
3. **Check Home providers** - Add try-catch to see if caseListProvider crashes
4. **Verify Routes.home** - Ensure `'/'` route is active in app_router

---

**End of Report**  
**Status:** PARTIAL SUCCESS - Legacy UI removed but navigation broken  
**Priority:** FIX black screen issue (navigation after scan)
