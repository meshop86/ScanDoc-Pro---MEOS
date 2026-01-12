# Phase 14.K – Kill Legacy Routing ✅ COMPLETE

## 1. Routing Changes (LEGACY KILLED)

### Removed Routes
- ❌ `Routes.tap` - DELETED from routes.dart
- ❌ `Routes.bo` - DELETED from routes.dart
- ❌ `Routes.capture` - DELETED from routes.dart
- ❌ `/tap/:tapId` route - DELETED from app_router.dart

### Active Routes Only
- ✅ `/` (home) → `HomeScreen` (from `home_screen_new.dart`)
- ✅ `/files` → `FilesScreen`
- ✅ `/scan` → `QuickScanScreen`
- ✅ `/tools` → `ToolsScreen`
- ✅ `/me` → `MeScreen`
- ✅ `/case/:caseId` → `CaseDetailScreen` (NEW)

## 2. Files Changed

### 1. Deleted: `lib/src/features/home/home_screen.dart`
**Status:** ✅ REMOVED
- **Reason:** Contained legacy Routes.tap navigation
- **Replacement:** home_screen_new.dart (already active)

### 2. Modified: `lib/src/routing/routes.dart`
**Changes:**
```dart
// REMOVED:
@Deprecated('Use /case instead')
static const tap = '/tap';
@Deprecated('Use /folder instead')
static const bo = '/bo';
@Deprecated('Use /scan instead')
static const capture = '/capture';
```

### 3. Modified: `lib/src/routing/app_router.dart`
**Changes:**
```dart
// REMOVED the legacy route:
GoRoute(
  path: '${Routes.tap}/:tapId',
  builder: (context, state) {
    return const HomeScreen();
  },
),
```
**Kept:** `/case/:caseId` route ONLY

### 4. Verified: `lib/src/features/home/home_screen_new.dart`
**Navigation Flow:**
```dart
// Line 273: Case card tap goes to NEW route
onTap: () {
  context.push('${Routes.caseDetail}/${caseData.id}');
}
```
✅ Correctly routes to `/case/{caseId}` = CaseDetailScreen

## 3. Entry Point Verification

| Action | Route | Screen | Status |
|--------|-------|--------|--------|
| Tap Home | `/` | HomeScreen (new) | ✅ Active |
| Tap Case Card | `/case/:caseId` | CaseDetailScreen | ✅ Active |
| Scan → Create Case | Auto Home | Case appears | ✅ Active |
| Old `/tap/xyz` | ❌ ROUTE DELETED | N/A | ✅ KILLED |

## 4. Build Status

```
✓ Build: iOS Release (24.1MB)
✓ Install: WiFi to physical iPhone
✓ Launch: App started successfully
```

## 5. Manual Verification Test (RUN NOW ON DEVICE)

### Test Case 1: Open any existing case
```
✅ Expected: Shows case name + page grid (2-column)
❌ MUST NOT: Show "Biển số" / "Tờ khai" / "Nguồn gốc" / "TAP_001"
```

### Test Case 2: View page
```
✅ Expected: Full-screen image viewer
❌ MUST NOT: Any vehicle terminology
```

### Test Case 3: Rename page
```
✅ Expected: Dialog → new name → persists (kill app + reopen)
❌ MUST NOT: Reference old "GiayTo" or "Tờ khai"
```

### Test Case 4: Delete page
```
✅ Expected: Page removed from grid
❌ MUST NOT: Legacy screens appear
```

### Test Case 5: PDF Export
```
✅ Expected: PDF with all pages, saves to Documents
❌ MUST NOT: Old document naming
```

---

## 🎯 SUCCESS CRITERIA

**✅ PASS IF:**
- Open Home → see Case list
- Tap any Case → see NEW CaseDetailScreen (page grid)
- NO old UI visible (no "Biển số", no "Tờ khai")
- Rename/Delete/Export work
- Build clean, 0 errors

**❌ FAIL IF:**
- Any "Biển số" / "Tờ khai" text appears
- Old tap_detail_screen opens
- Routes.tap still referenced
- /tap/:tapId route exists

---

## 📝 Summary

| Component | Before | After | Status |
|-----------|--------|-------|--------|
| Home Screen | home_screen.dart (legacy) | home_screen_new.dart | ✅ Switched |
| Case Route | /tap/:tapId | /case/:caseId | ✅ New only |
| Case Detail | tap_detail_screen (old) | case_detail_screen (NEW) | ✅ Active |
| Legacy Routes | tap, bo, capture | (DELETED) | ✅ KILLED |
| Build | Legacy refs exist | 0 legacy refs | ✅ Clean |

---

**Build Date:** 7 Jan 2026 @ 21:57  
**Device:** iPhone (00008120-00043D3E14A0C01E)  
**Phase:** 14.K – Kill Legacy Routing  
**Status:** ✅ **LEGACY ROUTING ELIMINATED**
