# Phase 13 – Structure & Flow Refactor Report

**Project**: ScanDoc Pro  
**Phase**: 13 - Navigation & Data Structure Refactor  
**Date**: January 7, 2026  
**Status**: ⚠️ **IN PROGRESS** - Foundation Complete, Integration Pending

---

## Executive Summary

Phase 13 aims to transform ScanDoc Pro from a vehicle document app into a professional document scanner with clear navigation and modern UX. The foundation has been laid with new data models, database schema, and UI components, but **full integration is not yet complete**.

### What's Done ✅
- New domain models (Case → Page with optional Folders)
- Database schema v2 with migration strategy
- Bottom navigation structure (5 tabs)
- New screen components (Files, Tools, Me, Quick Scan)
- Deprecated legacy models with backward compatibility

### What Remains ⚠️
- Wire new components into routing
- Remove all vehicle/plate references from active code
- Integrate scan engine with new flow
- Data migration utilities
- Full testing and validation

---

## 1. New App Flow

### A. Entry Flow
```
Login (non-blocking, optional)
   ↓
Bottom Navigation (5 tabs)
   ├─ Home: Case Library
   ├─ Files: All Pages (flat view)
   ├─ Scan: Quick Scan (center button)
   ├─ Tools: Placeholder features
   └─ Me: Account & settings
```

**Implementation Status**:
- ✅ Login screen preserved (already non-blocking)
- ✅ Bottom navigation component created (`MainNavigation`)
- ⚠️ Routing integration incomplete

### B. Home Structure - Case Library

**Old Flow** (Phase 12):
```
Cases (TapHoSo)
  └─ Document Sets (BoHoSo) - License plates
      └─ Documents (GiayTo) - Vehicle paperwork
          └─ Pages (images)
```

**New Flow** (Phase 13):
```
Cases (professional containers)
  ├─ Pages (direct attachment)
  └─ Folders (optional grouping)
      └─ Pages
```

**Implementation**:
- ✅ New data models created:
  - `Case`: Top-level container (name, description, status, created date)
  - `Folder`: Optional organization (name, description, page list)
  - `Page`: Scanned document page (image path, thumbnail, metadata)
- ✅ Database tables added:
  - `cases`, `folders`, `pages`
  - Legacy tables (`taps`, `bos`, `giaytos`) retained for migration
- ✅ Empty state UI created for Case Library
- ⚠️ Case list rendering incomplete
- ⚠️ Case detail screen not yet created

---

## 2. Navigation System

### Bottom Navigation Tabs

| Tab | Icon | Purpose | Status |
|-----|------|---------|--------|
| **Home** | 🏠 | Case Library - all user cases | ✅ Screen created |
| **Files** | 📁 | Flat view of all scanned pages | ✅ Screen created |
| **Scan** | 📷 | Quick Scan (center button) | ✅ Screen created |
| **Tools** | 🔧 | OCR, Edit, Cloud (placeholders) | ✅ Screen created |
| **Me** | 👤 | Account, Settings, PRO features | ✅ Screen created |

**Implementation**:
- ✅ `MainNavigation` widget created with `BottomNavigationBar`
- ✅ All 5 tab screens scaffolded
- ⚠️ GoRouter integration incomplete
- ⚠️ Navigation state management not wired

---

## 3. Scan Modes

### A. Quick Scan (QSCan)

**Purpose**: Fast, no-thinking scan for immediate document capture

**Flow**:
1. User taps Scan button (center tab)
2. Scan engine opens immediately (NO prompts)
3. User scans multiple pages continuously
4. All pages auto-saved to default "QSCan" case
5. User names/organizes pages AFTER scanning

**Implementation**:
- ✅ `QuickScanScreen` created with UI
- ✅ Multi-page scanning flow designed
- ⚠️ VisionKit/Camera integration pending
- ⚠️ Save to default "QSCan" case not implemented

**Key Requirement**: Use existing `scan_service.dart` - **DO NOT MODIFY SCAN ENGINE**

### B. Multi Scan

**Purpose**: Structured scanning within a specific Case/Folder context

**Flow**:
1. User opens a Case from Home
2. Optional: User creates/selects Folder
3. User taps "Scan" within Case
4. Pages saved directly to selected Case/Folder

**Implementation**:
- ⚠️ **NOT YET STARTED**
- Requires Case detail screen
- Requires Folder management UI
- Requires context-aware scan launcher

---

## 4. Removed Legacy Concepts

### Target for Complete Removal

The following vehicle-related concepts **must be eliminated**:

| Vietnamese | English | Context | Removal Status |
|------------|---------|---------|----------------|
| Biển số | License plate | Used as DocumentSet identifier | ⚠️ 50+ occurrences found |
| Tờ khai | Declaration form | Predefined document type | ⚠️ References in UI |
| Nguồn gốc | Origin/Source | Vehicle provenance field | ⚠️ In scan module |
| Bộ hồ sơ (BoHoSo) | Document Set | Middle layer (vehicle bundle) | ✅ Deprecated, kept for migration |
| Giấy tờ (GiayTo) | Document/Paper | Individual document entity | ✅ Deprecated, kept for migration |
| Tập hồ sơ (TapHoSo) | Case/Dossier | Top container (still used) | ✅ Deprecated, kept for migration |

### Deprecation Strategy

**Implemented**:
```dart
@Deprecated('Use Case instead. TapHoSo will be migrated to Case.')
class TapHoSo { ... }

@Deprecated('Use Folder instead. BoHoSo will be migrated to Folder.')
class BoHoSo { ... }

@Deprecated('Use Page instead. GiayTo represents old document model.')
class GiayTo { ... }
```

**Legacy Code Retention**:
- Old models kept in `models.dart` for backward compatibility
- Old database tables (`Taps`, `Bos`, `GiayTos`) retained for data migration
- Old API methods marked `@Deprecated` with migration hints

### Files Still Using Legacy Concepts

**Critical Files to Refactor**:
1. `lib/src/features/home/home_screen.dart` - Uses `TapHoSo`, `firstLicensePlate`
2. `lib/src/features/tap/tap_detail_screen.dart` - Entire file is legacy
3. `lib/src/features/tap/tap_controller.dart` - Uses `TapHoSo`, `BoHoSo`
4. `lib/src/services/storage/storage_service.dart` - Uses `licensePlate` in paths
5. `lib/scan/tap_page.dart` - Legacy scan UI with vehicle concepts

**Legacy Directory** (`lib/scan/`):
- Contains 25 files from previous phases
- Many use vehicle terminology
- Should be gradually replaced or refactored

---

## 5. Explicitly NOT Changed

### Protected Systems (DO NOT TOUCH)

✅ **Scan Engine**:
- `lib/scan/vision_scan_service.dart` - VisionKit wrapper
- `lib/scan/scan_service.dart` - Core scanning logic
- Native iOS scanning code - **FROZEN**

✅ **Export Logic**:
- `lib/scan/pdf_service.dart` - PDF generation
- `lib/src/services/zip/native_zip_service.dart` - ZIP packaging
- Share functionality - **STABLE**

✅ **Audit System**:
- `lib/scan/audit_service.dart` - Event logging
- `lib/scan/audit_events.dart` - Event definitions
- Admin audit viewer - **STABLE**

✅ **Offline Architecture**:
- Local-first data storage
- Drift database (SQLite)
- No backend dependencies - **CORE PRINCIPLE**

### Database Migration Strategy

**Schema Version**: 1 → 2

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll();
  },
  onUpgrade: (Migrator m, int from, int to) async {
    if (from == 1) {
      // Create new tables
      await m.createTable(cases);
      await m.createTable(folders);
      await m.createTable(pages);
      // Legacy tables remain for data migration
    }
  },
);
```

**Migration Utilities Needed**:
- `TapHoSo` → `Case` converter
- `BoHoSo` → `Folder` converter  
- `GiayTo` → `Page` converter
- File system path updater

⚠️ **Data Migration Not Yet Implemented**

---

## 6. Risks Checked

### A. Data Loss Risk ⚠️ **HIGH**

**Current State**:
- New tables created but not populated
- Old tables still contain user data
- No automatic migration in place

**Mitigation Needed**:
1. Create data migration service
2. Run migration on app startup
3. Validate data integrity
4. Keep old tables as backup

**User Impact**:
- ⚠️ If users update now, they'll see empty Case Library
- ⚠️ Old data still exists in database but not accessible via new UI

### B. Navigation Confusion Risk ⚠️ **MEDIUM**

**Current State**:
- Old routing still active (`/tap/:id`, `/bo/:id`)
- New routing defined but not integrated
- Two parallel navigation systems exist

**Mitigation Needed**:
1. Complete GoRouter integration
2. Remove old routes
3. Redirect old deep links to new structure

### C. Scan Engine Breakage Risk ✅ **LOW**

**Current State**:
- Scan engine files not modified
- New UI calls will need careful integration
- Existing scan flow still functional

**Protection**:
- Legacy scan pages still exist
- VisionKit wrapper unchanged
- Can fallback to old flow if needed

### D. Destructive Actions Risk ✅ **LOW**

**Current State**:
- Delete operations not yet implemented in new UI
- Legacy delete functions still exist but not exposed
- No accidental deletion paths in new screens

**Future Consideration**:
- Add confirmation dialogs for Case deletion
- Implement soft delete (archive) before hard delete
- Add "Recently Deleted" recovery option

---

## 7. Implementation Progress

### Completed ✅

**Data Layer**:
- [x] New domain models (Case, Folder, Page)
- [x] Database schema v2 with migration hooks
- [x] Deprecation markers on legacy models
- [x] Database code generation

**UI Layer**:
- [x] Bottom navigation shell
- [x] Home screen (new, empty state only)
- [x] Files screen (placeholder)
- [x] Tools screen (placeholder)
- [x] Me screen (full implementation)
- [x] Quick Scan screen (UI only)

**Routing**:
- [x] New route definitions
- [x] Legacy route deprecation markers

### In Progress ⚠️

**Integration**:
- [ ] Wire bottom navigation to GoRouter
- [ ] Connect Home screen to database
- [ ] Implement Case detail screen
- [ ] Connect Quick Scan to scan engine

**Data Migration**:
- [ ] Tap → Case migration service
- [ ] Bo → Folder migration service
- [ ] GiayTo → Page migration service
- [ ] File system path migration

### Not Started ❌

**Critical Path**:
- [ ] Multi Scan implementation
- [ ] Folder management UI
- [ ] Case CRUD operations
- [ ] Page management and display
- [ ] Search functionality
- [ ] Export with new structure

**Legacy Cleanup**:
- [ ] Remove vehicle terminology from active code
- [ ] Refactor `tap_controller.dart`
- [ ] Refactor `tap_detail_screen.dart`
- [ ] Update `storage_service.dart` paths
- [ ] Clean up `lib/scan/` directory

**Testing**:
- [ ] Unit tests for new models
- [ ] Integration tests for migration
- [ ] UI tests for new screens
- [ ] Regression tests for scan engine
- [ ] Export/ZIP validation

---

## 8. Next Steps (Priority Order)

### Phase 13.1 - Integration (CRITICAL)
1. **Wire Bottom Navigation**
   - Integrate `MainNavigation` with GoRouter
   - Set up StatefulShellRoute for tab persistence
   - Test navigation flow

2. **Implement Data Migration**
   - Create migration service
   - Run on app startup (one-time)
   - Validate data integrity
   - Add rollback mechanism

3. **Connect Home Screen**
   - Load Cases from database
   - Display Case cards
   - Implement Case creation
   - Add search/filter

### Phase 13.2 - Case Management
1. **Create Case Detail Screen**
   - Show Pages and Folders
   - Add/remove items
   - Edit Case metadata
   - Delete Case (with confirmation)

2. **Implement Folder Management**
   - Create/rename Folders
   - Move Pages between Folders
   - Delete Folders

### Phase 13.3 - Scan Integration
1. **Connect Quick Scan**
   - Wire to existing scan engine
   - Save to "QSCan" default Case
   - Display scanned pages
   - Implement post-scan naming

2. **Implement Multi Scan**
   - Context-aware scan launcher
   - Save to selected Case/Folder
   - Batch operations

### Phase 13.4 - Legacy Cleanup
1. **Remove Vehicle References**
   - Search and replace UI strings
   - Refactor active controllers
   - Update storage paths
   - Clean up deprecated code

2. **Testing & Validation**
   - Verify scan engine integrity
   - Test export flows (PDF/ZIP)
   - Validate audit logging
   - Performance testing

---

## 9. Code Structure

### New Files Created

```
lib/src/
├── domain/
│   └── models.dart (✅ Updated with new models)
├── data/
│   └── database/
│       └── database.dart (✅ Schema v2 + migration)
├── features/
│   ├── navigation/
│   │   └── main_navigation.dart (✅ NEW)
│   ├── home/
│   │   └── home_screen_new.dart (✅ NEW)
│   ├── files/
│   │   └── files_screen.dart (✅ NEW)
│   ├── tools/
│   │   └── tools_screen.dart (✅ NEW)
│   ├── me/
│   │   └── me_screen.dart (✅ NEW)
│   └── scan/
│       └── quick_scan_screen.dart (✅ NEW)
└── routing/
    └── routes.dart (✅ Updated)
```

### Legacy Files to Refactor

```
lib/src/features/
├── home/
│   └── home_screen.dart (⚠️ Uses TapHoSo)
├── tap/
│   ├── tap_controller.dart (⚠️ Uses legacy models)
│   └── tap_detail_screen.dart (⚠️ Entire file legacy)
└── services/
    └── storage/
        └── storage_service.dart (⚠️ licensePlate in paths)
```

---

## 10. Breaking Changes

### For Users
- ⚠️ UI completely redesigned (new navigation)
- ⚠️ Data migration required on first launch
- ⚠️ Old terminology replaced with neutral language
- ✅ No data loss (migration preserves everything)

### For Developers
- ⚠️ New domain models required for new features
- ⚠️ Old models deprecated (will be removed in Phase 14)
- ⚠️ Routing structure completely changed
- ⚠️ Database schema v2 requires code regeneration

---

## 11. Success Criteria (Phase 13 Complete)

### Must Have ✅
- [ ] Bottom navigation functional
- [ ] Case Library displays user cases
- [ ] Quick Scan creates pages in default case
- [ ] All vehicle references removed from active UI
- [ ] Data migration successful (zero data loss)
- [ ] Scan engine unchanged and functional
- [ ] Export (PDF/ZIP) working with new structure

### Should Have
- [ ] Folder management UI
- [ ] Multi Scan implementation
- [ ] Search functionality
- [ ] Case detail screen with full CRUD
- [ ] Files view showing all pages

### Nice to Have
- [ ] Tools screen features (OCR placeholder working)
- [ ] Me screen fully functional
- [ ] Performance optimizations
- [ ] Onboarding tutorial for new flow

---

## 12. Timeline Estimate

| Phase | Tasks | Effort | Status |
|-------|-------|--------|--------|
| 13.0 - Foundation | Models, DB, UI scaffolding | 6h | ✅ Done |
| 13.1 - Integration | Navigation, Migration, Home | 8h | ⚠️ Current |
| 13.2 - Case Mgmt | Detail screens, CRUD | 6h | ❌ Pending |
| 13.3 - Scan | QScan integration, Multi Scan | 8h | ❌ Pending |
| 13.4 - Cleanup | Remove legacy, Testing | 6h | ❌ Pending |
| **Total** | | **34h** | **18% Complete** |

---

## 13. Recommendations

### Immediate Actions
1. ⚠️ **DO NOT DEPLOY** - Phase 13 incomplete, will break user experience
2. ✅ **Complete Phase 13.1** before moving to new features
3. ✅ **Test data migration** thoroughly on test devices first
4. ✅ **Keep legacy code** until migration proven successful

### Long-term Strategy
1. Consider feature flags for gradual rollout
2. Add analytics to track migration success rate
3. Provide "Classic View" fallback option
4. Plan Phase 14 for complete legacy code removal

---

## Appendix A: Database Schema

### New Tables (Phase 13)

**cases**
```sql
CREATE TABLE cases (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL,  -- active|completed|archived
  created_at INTEGER NOT NULL,
  completed_at INTEGER,
  owner_user_id TEXT NOT NULL
);
```

**folders**
```sql
CREATE TABLE folders (
  id TEXT PRIMARY KEY,
  case_id TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

**pages**
```sql
CREATE TABLE pages (
  id TEXT PRIMARY KEY,
  case_id TEXT NOT NULL,
  folder_id TEXT,  -- NULL = not in folder
  name TEXT NOT NULL,
  image_path TEXT NOT NULL,
  thumbnail_path TEXT,
  page_number INTEGER,
  status TEXT NOT NULL,  -- captured|processing|ready
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### Legacy Tables (Retained)

- `taps` (TapHoSo)
- `bos` (BoHoSo)  
- `giaytos` (GiayTo)
- `users` (unchanged)

---

## Appendix B: Migration Pseudocode

```dart
Future<void> migratePhase13() async {
  // 1. Check if migration already done
  final migrationFlag = await prefs.getBool('phase13_migrated');
  if (migrationFlag == true) return;

  // 2. Migrate Taps → Cases
  final taps = await db.getAllTaps();
  for (final tap in taps) {
    final caseData = CasesCompanion(
      id: Value(tap.id),
      name: Value(tap.code),
      status: Value(tap.status == TapStatus.completed ? 'completed' : 'active'),
      createdAt: Value(tap.createdAt),
      completedAt: Value(tap.completedAt),
      ownerUserId: Value(tap.ownerUserId),
    );
    await db.createCase(caseData);

    // 3. Migrate Bos → Folders
    final bos = await db.getBosByTap(tap.id);
    for (final bo in bos) {
      final folderData = FoldersCompanion(
        id: Value(bo.id),
        caseId: Value(tap.id),
        name: Value(bo.licensePlate),  // License plate becomes folder name
        createdAt: Value(bo.createdAt),
        updatedAt: Value(bo.updatedAt),
      );
      await db.createFolder(folderData);

      // 4. Migrate GiayTos → Pages
      final giaytos = await db.getGiayTosByBo(bo.id);
      for (final giayto in giaytos) {
        if (giayto.imagePath == null) continue;  // Skip missing docs
        
        final pageData = PagesCompanion(
          id: Value(giayto.id),
          caseId: Value(tap.id),
          folderId: Value(bo.id),
          name: Value(giayto.name),
          imagePath: Value(giayto.imagePath!),
          status: const Value('ready'),
          createdAt: Value(giayto.createdAt),
          updatedAt: Value(giayto.updatedAt),
        );
        await db.createPage(pageData);
      }
    }
  }

  // 5. Mark migration complete
  await prefs.setBool('phase13_migrated', true);
}
```

---

## Conclusion

Phase 13 has successfully laid the **foundation** for ScanDoc Pro's transformation into a professional document scanner. The new domain models, database schema, and UI components are in place, but **integration work remains critical** before deployment.

**Current Risk Level**: ⚠️ **HIGH** - Incomplete migration could cause data loss or user confusion

**Recommendation**: Complete Phase 13.1 (Integration) before any production release.

---

**Prepared by**: VSC – Senior Flutter Engineer  
**Review Status**: Awaiting Product Owner approval  
**Next Review**: After Phase 13.1 completion
