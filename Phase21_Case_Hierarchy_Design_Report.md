# Phase 21: Case Hierarchy (1-Level) - Design & Analysis Report

**Status:** 📋 Design Phase  
**Date:** 2026-01-10  
**Type:** Database Schema Extension + Business Logic

---

## 1. Executive Summary

**Objective:** Implement 1-level case hierarchy to support **Group Cases** (folders of cases).

**Key Requirements:**
- ✅ Add `parentCaseId` (nullable) to Cases table
- ✅ Add `isGroup` (boolean) to Cases table
- ✅ Safe migration (v3 → v4) with zero data loss
- ✅ Group Cases cannot scan pages
- ✅ Group Cases cannot export
- ✅ Pages and Exports schemas unchanged
- ✅ Backward compatibility preserved

**Design Philosophy:**
- **Data Safety First:** Existing cases remain functional
- **Guard Logic:** Prevent invalid operations at database + service layer
- **No UI Changes Yet:** Schema and business logic only

---

## 2. Current State Analysis

### 2.1 Current Database Schema (v3)

**Cases Table:**
```dart
class Cases extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()(); // active, completed, archived
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get ownerUserId => text()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Current Domain Model:**
```
User
  └── Case (flat list)
       ├── Folder (optional organization)
       │    └── Page
       └── Page (unfiled)
       └── Export (Phase 20)
```

**Current Relationships:**
- Case ⇄ Page (1:N)
- Case ⇄ Folder (1:N)
- Case ⇄ Export (1:N)
- Folder ⇄ Page (1:N, optional)

**Current Constraints:**
- ✅ All cases can be scanned
- ✅ All cases can be exported
- ✅ No case hierarchy (flat structure)

### 2.2 Current API Usage

**Creation Points:**
```dart
// Quick Scan creates case
await database.createCase(
  db.CasesCompanion(
    id: Value(caseId),
    name: Value('Scan ${timestamp}'),
    status: const Value('active'),
    createdAt: Value(DateTime.now()),
    ownerUserId: Value(currentUser.id),
  ),
);
```

**Query Points:**
```dart
// Get all cases (home screen)
await database.getAllCases()

// Get case details
await database.getCase(caseId)

// Get pages by case
await database.getPagesByCase(caseId)

// Get exports by case
await database.getExportsByCase(caseId)
```

**Update Points:**
```dart
// Update case (status changes)
await database.updateCase(casesCompanion)

// Delete case (cascading delete handled by UI)
await database.deleteCase(caseId)
```

---

## 3. Proposed Schema Changes

### 3.1 Enhanced Cases Table (v4)

```dart
class Cases extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()(); // active, completed, archived
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get ownerUserId => text()();
  
  // ============ PHASE 21: HIERARCHY SUPPORT ============
  /// Parent case ID for 1-level hierarchy
  /// - NULL: Top-level case (root)
  /// - Non-NULL: Child case (belongs to group)
  TextColumn get parentCaseId => text().nullable()();
  
  /// Whether this case is a group (folder of cases)
  /// - TRUE: Group case (can contain child cases, cannot scan/export)
  /// - FALSE: Regular case (cannot contain children, can scan/export)
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  // ====================================================

  @override
  Set<Column> get primaryKey => {id};
}
```

**New Columns:**
1. **`parentCaseId`** (TEXT, NULLABLE)
   - Foreign key to Cases.id
   - NULL = top-level case
   - Non-NULL = child of specified group case
   - Self-referencing relationship

2. **`isGroup`** (BOOLEAN, DEFAULT FALSE)
   - TRUE = Group case (container)
   - FALSE = Regular case (content)
   - Determines allowed operations

### 3.2 New Domain Model

```
User
  └── Group Case (isGroup=TRUE, parentCaseId=NULL)
       └── Regular Case (isGroup=FALSE, parentCaseId=<group-id>)
            ├── Folder (unchanged)
            │    └── Page
            └── Page (unfiled)
            └── Export (Phase 20)
  └── Regular Case (isGroup=FALSE, parentCaseId=NULL)
       ├── Folder
       └── Page
       └── Export
```

**Hierarchy Rules:**
- **Max Depth:** 1 level (Group → Regular Case)
- **No Nesting:** Group Cases cannot contain other Group Cases
- **Root Cases:** Can be either Group or Regular (parentCaseId = NULL)

### 3.3 New Relationships

**Parent-Child:**
```sql
-- Self-referencing foreign key (logical, not enforced)
parentCaseId → Cases.id

-- Examples:
-- Group Case:    id=G1, isGroup=TRUE,  parentCaseId=NULL
-- Child Case A:  id=C1, isGroup=FALSE, parentCaseId=G1
-- Child Case B:  id=C2, isGroup=FALSE, parentCaseId=G1
-- Standalone:    id=S1, isGroup=FALSE, parentCaseId=NULL
```

**Constraint Matrix:**

| Case Type | parentCaseId | isGroup | Can Scan | Can Export | Can Contain Cases |
|-----------|-------------|---------|----------|------------|------------------|
| **Group Case (Root)** | NULL | TRUE | ❌ | ❌ | ✅ |
| **Regular Case (Root)** | NULL | FALSE | ✅ | ✅ | ❌ |
| **Child Case** | <group-id> | FALSE | ✅ | ✅ | ❌ |

**Invalid States:**

| parentCaseId | isGroup | Valid? | Reason |
|--------------|---------|--------|--------|
| NULL | TRUE | ✅ | Root group case |
| NULL | FALSE | ✅ | Root regular case |
| <group-id> | FALSE | ✅ | Child case under group |
| **<group-id>** | **TRUE** | ❌ | **Cannot nest groups** |

---

## 4. Migration Strategy

### 4.1 Migration Plan (v3 → v4)

**Schema Version:** 3 → 4

```dart
@override
int get schemaVersion => 4; // Updated for Phase 21

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll();
  },
  onUpgrade: (Migrator m, int from, int to) async {
    // ... existing migrations (v1→v2, v2→v3)
    
    if (from <= 3 && to >= 4) {
      // Phase 21: Add hierarchy support to Cases table
      
      // Step 1: Add parentCaseId column (nullable, defaults to NULL)
      await m.addColumn(cases, cases.parentCaseId);
      
      // Step 2: Add isGroup column (boolean, defaults to FALSE)
      await m.addColumn(cases, cases.isGroup);
      
      print('✅ Phase 21 migration: Added parentCaseId + isGroup to Cases');
      
      // No data migration needed:
      // - All existing cases: parentCaseId=NULL (top-level)
      // - All existing cases: isGroup=FALSE (regular cases)
      // - Existing functionality preserved
    }
  },
);
```

**Migration Safety:**
- ✅ **Additive Only:** No columns dropped or renamed
- ✅ **Default Values:** New columns have safe defaults (NULL, FALSE)
- ✅ **Zero Data Loss:** Existing cases unchanged
- ✅ **Backward Compatible:** Old queries still work
- ✅ **Idempotent:** Can run multiple times safely

### 4.2 Migration Risks & Mitigation

#### Risk 1: Migration Failure Mid-Way

**Scenario:** App crashes during `addColumn()` operation

**Impact:**
- Database in inconsistent state
- One column added, other missing
- App may crash on next launch

**Mitigation:**
- SQLite transactions are atomic (both columns or neither)
- Drift handles migration rollback automatically
- If failure: User reinstalls app or clears data (no cloud backup)

**Probability:** Very Low (SQLite ALTER TABLE is atomic)

---

#### Risk 2: Existing Code Breaks

**Scenario:** Old code doesn't handle new columns

**Impact:**
- CasesCompanion creation without new fields
- Generated code (database.g.dart) includes new fields

**Mitigation:**
- New columns are **nullable** or have **defaults**
- Old code can use `Value.absent()` implicitly
- Generated Companion classes handle missing values
- Example:
  ```dart
  // Old code (still works):
  CasesCompanion(
    id: Value(id),
    name: Value(name),
    // parentCaseId: implicitly Value.absent() → NULL
    // isGroup: implicitly Value.absent() → FALSE
  )
  ```

**Probability:** Very Low (Drift design handles this)

---

#### Risk 3: Foreign Key Integrity

**Scenario:** parentCaseId references non-existent case

**Impact:**
- Orphaned child cases
- UI shows broken hierarchy
- Cascade delete issues

**Mitigation:**
- **No Database Constraint:** parentCaseId is logical, not enforced by FK
- **Application-Level Validation:** Guard logic checks parent exists
- **Cascade Delete Strategy:** Delete children when parent group deleted
- **Query-Time Handling:** Filter out orphans in UI

**Probability:** Low (guard logic prevents invalid states)

---

#### Risk 4: Circular References

**Scenario:** Case A → Case B → Case A (shouldn't happen with 1-level)

**Impact:**
- Infinite loops in queries
- Stack overflow in recursive functions

**Mitigation:**
- **1-Level Constraint:** Only Group Cases (root) can be parents
- **Validation:** Reject setting parentCaseId on Group Cases
- **Guard Logic:** `isGroup==TRUE → parentCaseId must be NULL`

**Probability:** Zero (prevented by business rules)

---

#### Risk 5: Group Case Gets Pages/Exports

**Scenario:** User scans into Group Case or exports Group Case

**Impact:**
- Conceptual confusion (groups shouldn't have content)
- Export fails (no pages to export)

**Mitigation:**
- **Database Layer:** No constraint (allows flexibility)
- **Service Layer:** Validation checks `isGroup` before operations
- **UI Layer:** Disable scan/export buttons for groups
- **Cleanup:** If pages exist on group, they're ignored or moved

**Probability:** Medium (depends on implementation discipline)

---

### 4.3 Rollback Strategy

**If Phase 21 needs to be reverted:**

**Option 1: Schema Rollback (Dangerous)**
```sql
-- NOT RECOMMENDED: Dropping columns loses data
ALTER TABLE cases DROP COLUMN parentCaseId;
ALTER TABLE cases DROP COLUMN isGroup;
```
❌ **Don't do this:** Loses hierarchy information

**Option 2: Ignore New Columns (Safe)**
```dart
// Keep schema at v4, but don't use new fields
// All queries continue to work
// UI doesn't show hierarchy
// New columns stay NULL/FALSE
```
✅ **Recommended:** No data loss, can re-enable later

**Option 3: Database Reset (Nuclear)**
```dart
// Delete scandoc_pro.db file
// Recreate from scratch
// User loses all data
```
❌ **Last Resort Only:** For critical failures

---

## 5. Business Logic & Guard Rules

### 5.1 Case Creation Rules

**Creating Regular Case:**
```dart
// Standalone regular case
CasesCompanion(
  id: Value(uuid),
  name: Value('My Case'),
  isGroup: Value(false),       // Required: explicit FALSE
  parentCaseId: Value(null),   // NULL = top-level
  // ... other fields
)

// Child case under group
CasesCompanion(
  id: Value(uuid),
  name: Value('Child Case'),
  isGroup: Value(false),       // Must be FALSE
  parentCaseId: Value(groupId), // Must reference valid Group Case
  // ... other fields
)
```

**Creating Group Case:**
```dart
// Group case (container only)
CasesCompanion(
  id: Value(uuid),
  name: Value('Project X'),
  isGroup: Value(true),        // Required: explicit TRUE
  parentCaseId: Value(null),   // Must be NULL (no nesting)
  // ... other fields
)
```

**Validation Rules:**
```dart
class CaseValidation {
  /// Validate case creation
  static String? validateCreate(CasesCompanion companion) {
    final isGroup = companion.isGroup.value;
    final parentCaseId = companion.parentCaseId.value;
    
    // Rule 1: Group cases must be root-level
    if (isGroup && parentCaseId != null) {
      return '❌ Group cases cannot have a parent (no nesting)';
    }
    
    // Rule 2: Child cases must be regular (not groups)
    if (parentCaseId != null && isGroup) {
      return '❌ Child cases cannot be groups';
    }
    
    return null; // Valid
  }
  
  /// Validate case update
  static String? validateUpdate(
    Case existingCase,
    CasesCompanion updates,
  ) {
    // Prevent changing isGroup if case has pages
    if (updates.isGroup.present && 
        updates.isGroup.value != existingCase.isGroup &&
        existingCase.hasPages) { // need to check
      return '❌ Cannot change case type: case has scanned pages';
    }
    
    // Prevent setting parent if case is a group
    if (existingCase.isGroup && updates.parentCaseId.present) {
      return '❌ Group cases cannot be moved under another case';
    }
    
    return null; // Valid
  }
}
```

### 5.2 Scan Operation Rules

**Guard Logic:**
```dart
class ScanGuard {
  /// Check if case can be scanned
  static Future<bool> canScan(AppDatabase db, String caseId) async {
    final caseData = await db.getCase(caseId);
    
    if (caseData == null) {
      return false; // Case not found
    }
    
    if (caseData.isGroup) {
      return false; // ❌ Cannot scan into Group Cases
    }
    
    return true; // ✅ Regular case, can scan
  }
  
  /// Enforce scan guard before VisionKit
  static Future<void> scanPages(
    AppDatabase db,
    String caseId,
    // ... scan parameters
  ) async {
    if (!await canScan(db, caseId)) {
      throw Exception('Cannot scan: case is a group');
    }
    
    // Proceed with VisionKit scan
    // ... (existing scan logic)
  }
}
```

**UI Integration:**
```dart
// Quick Scan button disabled if current case is group
final canScan = !caseData.isGroup;

FloatingActionButton(
  onPressed: canScan ? _startScan : null, // Disable if group
  child: Icon(Icons.camera),
)
```

### 5.3 Export Operation Rules

**Guard Logic:**
```dart
class ExportGuard {
  /// Check if case can be exported
  static Future<bool> canExport(AppDatabase db, String caseId) async {
    final caseData = await db.getCase(caseId);
    
    if (caseData == null) {
      return false; // Case not found
    }
    
    if (caseData.isGroup) {
      return false; // ❌ Cannot export Group Cases
    }
    
    final pages = await db.getPagesByCase(caseId);
    if (pages.isEmpty) {
      return false; // ❌ No pages to export
    }
    
    return true; // ✅ Regular case with pages
  }
  
  /// Enforce export guard
  static Future<String?> exportCase(
    AppDatabase db,
    ExportService exportService,
    String caseId,
    String format, // 'PDF' or 'ZIP'
  ) async {
    if (!await canExport(db, caseId)) {
      throw Exception('Cannot export: case is a group or has no pages');
    }
    
    // Proceed with export
    final pages = await db.getPagesByCase(caseId);
    final imagePaths = pages.map((p) => p.imagePath).toList();
    
    if (format == 'PDF') {
      return await exportService.exportPDF(
        caseName: caseData.name,
        imagePaths: imagePaths,
      );
    } else {
      return await exportService.exportZIP(
        caseName: caseData.name,
        imagePaths: imagePaths,
      );
    }
  }
}
```

**UI Integration:**
```dart
// Export menu disabled if case is group
final canExport = !caseData.isGroup && pageCount > 0;

PopupMenuButton(
  enabled: canExport, // Disable if group
  itemBuilder: (context) => [
    PopupMenuItem(value: 'PDF', child: Text('Export as PDF')),
    PopupMenuItem(value: 'ZIP', child: Text('Export as ZIP')),
  ],
)
```

### 5.4 Delete Operation Rules

**Cascade Delete Strategy:**

```dart
class DeleteGuard {
  /// Delete case with cascade handling
  static Future<void> deleteCase(
    AppDatabase db,
    String caseId,
  ) async {
    final caseData = await db.getCase(caseId);
    if (caseData == null) return;
    
    if (caseData.isGroup) {
      // Group case: handle children
      final childCases = await db.getChildCases(caseId);
      
      if (childCases.isNotEmpty) {
        // Strategy 1: Prevent deletion (require empty group)
        throw Exception(
          'Cannot delete group: contains ${childCases.length} cases'
        );
        
        // OR Strategy 2: Cascade delete children
        // for (final child in childCases) {
        //   await deleteCase(db, child.id); // Recursive
        // }
        
        // OR Strategy 3: Orphan children (move to root)
        // for (final child in childCases) {
        //   await db.updateCase(
        //     child.copyWith(parentCaseId: null).toCompanion(true),
        //   );
        // }
      }
    } else {
      // Regular case: delete pages, exports, folders
      final pages = await db.getPagesByCase(caseId);
      for (final page in pages) {
        await db.deletePage(page.id);
        // Delete image files (existing logic)
      }
      
      final exports = await db.getExportsByCase(caseId);
      for (final export in exports) {
        await db.deleteExport(export.id);
        // Delete export files (existing logic)
      }
      
      final folders = await db.getFoldersByCase(caseId);
      for (final folder in folders) {
        await db.deleteFolder(folder.id);
      }
    }
    
    // Finally, delete the case
    await db.deleteCase(caseId);
  }
}
```

**Recommended Strategy:**
- **Group Cases:** Require empty before delete (prevent accidental data loss)
- **Regular Cases:** Cascade delete all content (existing behavior)

---

## 6. New Database API

### 6.1 Hierarchy Queries

**Add to AppDatabase class:**

```dart
// ========================================================================
// PHASE 21: HIERARCHY API
// ========================================================================

/// Get all top-level cases (no parent)
Future<List<Case>> getTopLevelCases() =>
    (select(cases)
      ..where((c) => c.parentCaseId.isNull())
      ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
    .get();

/// Get all group cases (isGroup = TRUE)
Future<List<Case>> getGroupCases() =>
    (select(cases)
      ..where((c) => c.isGroup.equals(true))
      ..orderBy([(c) => OrderingTerm.asc(c.name)]))
    .get();

/// Get all child cases under a parent group
Future<List<Case>> getChildCases(String parentCaseId) =>
    (select(cases)
      ..where((c) => c.parentCaseId.equals(parentCaseId))
      ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
    .get();

/// Get parent case of a child case
Future<Case?> getParentCase(String childCaseId) async {
  final child = await getCase(childCaseId);
  if (child == null || child.parentCaseId == null) {
    return null;
  }
  return await getCase(child.parentCaseId!);
}

/// Check if case is a group
Future<bool> isGroupCase(String caseId) async {
  final caseData = await getCase(caseId);
  return caseData?.isGroup ?? false;
}

/// Check if case can be scanned (not a group)
Future<bool> canScanCase(String caseId) async {
  return !(await isGroupCase(caseId));
}

/// Check if case can be exported (not a group, has pages)
Future<bool> canExportCase(String caseId) async {
  if (await isGroupCase(caseId)) return false;
  final pages = await getPagesByCase(caseId);
  return pages.isNotEmpty;
}

/// Get case hierarchy path (for breadcrumbs)
/// Returns: [Group Case, Child Case] or [Root Case]
Future<List<Case>> getCaseHierarchyPath(String caseId) async {
  final path = <Case>[];
  Case? current = await getCase(caseId);
  
  while (current != null) {
    path.insert(0, current); // Prepend to build top-down path
    
    if (current.parentCaseId == null) break; // Reached root
    current = await getCase(current.parentCaseId!);
  }
  
  return path;
}

/// Count child cases under group
Future<int> getChildCaseCount(String parentCaseId) async {
  final children = await getChildCases(parentCaseId);
  return children.length;
}

/// Move case to different parent (or root)
Future<void> moveCaseToParent(String caseId, String? newParentId) async {
  final caseData = await getCase(caseId);
  if (caseData == null) return;
  
  // Validation: Cannot move group under another case
  if (caseData.isGroup && newParentId != null) {
    throw Exception('Cannot move group case under another case');
  }
  
  // Validation: Parent must be a group case
  if (newParentId != null) {
    final parent = await getCase(newParentId);
    if (parent == null || !parent.isGroup) {
      throw Exception('Parent must be a group case');
    }
  }
  
  // Update parent
  await updateCase(
    caseData.copyWith(parentCaseId: Value(newParentId)).toCompanion(true),
  );
}
```

### 6.2 Updated Existing Queries

**Modified Queries:**

```dart
// Change getAllCases() to only return top-level cases
// (UI will load children on-demand)
Future<List<Case>> getAllCases() => getTopLevelCases();

// OR keep getAllCases() unchanged for compatibility
// and add getTopLevelCases() as separate query
```

**Recommendation:** Keep `getAllCases()` unchanged (returns all cases flat). Add `getTopLevelCases()` for hierarchy view.

---

## 7. Implementation Phases

### 7.1 Phase 21.1: Schema + Migration (DATA LAYER ONLY)

**Goal:** Add columns, migrate safely, no behavior change

**Tasks:**
1. ✅ Update `Cases` table in database.dart
   - Add `parentCaseId` column (nullable)
   - Add `isGroup` column (boolean, default FALSE)
2. ✅ Update `schemaVersion` to 4
3. ✅ Add migration in `onUpgrade()`
   - `await m.addColumn(cases, cases.parentCaseId);`
   - `await m.addColumn(cases, cases.isGroup);`
4. ✅ Run `dart run build_runner build --delete-conflicting-outputs`
5. ✅ Test migration on device
6. ✅ Verify existing cases still work

**Success Criteria:**
- ✅ App builds successfully
- ✅ Migration runs without errors
- ✅ Existing cases still display
- ✅ Existing scan/export still works
- ✅ New columns present in database

**Risk:** Very Low (additive schema change)

---

### 7.2 Phase 21.2: Hierarchy API (SERVICE LAYER)

**Goal:** Add query methods for hierarchy operations

**Tasks:**
1. ✅ Add hierarchy queries to AppDatabase:
   - `getTopLevelCases()`
   - `getGroupCases()`
   - `getChildCases(parentCaseId)`
   - `getParentCase(childCaseId)`
   - `getCaseHierarchyPath(caseId)`
2. ✅ Add guard methods:
   - `isGroupCase(caseId)`
   - `canScanCase(caseId)`
   - `canExportCase(caseId)`
3. ✅ Add management methods:
   - `moveCaseToParent(caseId, parentId)`
   - `getChildCaseCount(parentId)`
4. ✅ Test queries manually (no UI changes)

**Success Criteria:**
- ✅ Queries return expected results
- ✅ Guards prevent invalid operations
- ✅ No breaking changes to existing API

**Risk:** Low (new methods, don't affect existing code)

---

### 7.3 Phase 21.3: Guard Logic (BUSINESS RULES)

**Goal:** Enforce constraints at service/repository layer

**Tasks:**
1. ✅ Create `CaseValidation` class (validation logic)
2. ✅ Create `ScanGuard` class (scan operation guards)
3. ✅ Create `ExportGuard` class (export operation guards)
4. ✅ Create `DeleteGuard` class (cascade delete handling)
5. ✅ Integrate guards into existing services:
   - Quick Scan: Check `canScanCase()` before scan
   - Export: Check `canExportCase()` before export
   - Delete: Use `DeleteGuard.deleteCase()`
6. ✅ Write unit tests for guards

**Success Criteria:**
- ✅ Cannot scan into group cases
- ✅ Cannot export group cases
- ✅ Cannot create nested groups
- ✅ Cascade delete works correctly

**Risk:** Medium (behavior changes, needs testing)

---

### 7.4 Phase 21.4: UI Integration (FUTURE)

**Goal:** Update UI to show hierarchy (NOT IN SCOPE YET)

**Tasks (Future):**
1. ⏸️ Update Home screen to show group/child structure
2. ⏸️ Add "Create Group" button
3. ⏸️ Add "Move to Group" action
4. ⏸️ Show breadcrumb navigation for child cases
5. ⏸️ Disable scan/export buttons for group cases
6. ⏸️ Update case list to expand/collapse groups

**Not Started:** Waiting for Phase 21.1-21.3 completion

---

## 8. Testing Strategy

### 8.1 Migration Testing

**Test Cases:**

1. **Fresh Install (v4):**
   - Install app → Create case → Verify schema v4
   - Expected: New columns present, defaults applied

2. **Upgrade (v3 → v4):**
   - Install v3 → Create 5 cases → Upgrade to v4
   - Expected: All cases preserved, new columns added (NULL/FALSE)

3. **Upgrade with Data (v3 → v4):**
   - Install v3 → Create cases with pages/exports
   - Upgrade to v4
   - Verify scan/export still works
   - Expected: No data loss, functionality unchanged

4. **Downgrade (v4 → v3):** NOT SUPPORTED
   - Dropping columns loses data
   - Users must uninstall/reinstall

### 8.2 Guard Logic Testing

**Test Scenarios:**

**Group Case Guards:**
```dart
test('Group case cannot be scanned', () async {
  final groupId = 'group-1';
  await db.createCase(CasesCompanion(
    id: Value(groupId),
    name: Value('My Group'),
    isGroup: Value(true),
    // ...
  ));
  
  final canScan = await db.canScanCase(groupId);
  expect(canScan, false);
});

test('Group case cannot be exported', () async {
  final groupId = 'group-1';
  await db.createCase(CasesCompanion(
    id: Value(groupId),
    isGroup: Value(true),
    // ...
  ));
  
  final canExport = await db.canExportCase(groupId);
  expect(canExport, false);
});
```

**Hierarchy Validation:**
```dart
test('Group case cannot have parent', () {
  final companion = CasesCompanion(
    id: Value('group-1'),
    isGroup: Value(true),
    parentCaseId: Value('parent-1'), // ❌ Invalid
    // ...
  );
  
  final error = CaseValidation.validateCreate(companion);
  expect(error, isNotNull);
  expect(error, contains('cannot have a parent'));
});

test('Child case must be regular', () {
  final companion = CasesCompanion(
    id: Value('child-1'),
    isGroup: Value(true), // ❌ Invalid
    parentCaseId: Value('parent-1'),
    // ...
  );
  
  final error = CaseValidation.validateCreate(companion);
  expect(error, isNotNull);
});
```

**Cascade Delete:**
```dart
test('Cannot delete group with children', () async {
  final groupId = 'group-1';
  final childId = 'child-1';
  
  await db.createCase(CasesCompanion(id: Value(groupId), isGroup: Value(true)));
  await db.createCase(CasesCompanion(id: Value(childId), parentCaseId: Value(groupId)));
  
  expect(
    () => DeleteGuard.deleteCase(db, groupId),
    throwsException,
  );
});
```

### 8.3 Query Testing

**Hierarchy Queries:**
```dart
test('getChildCases returns only children', () async {
  final groupId = 'group-1';
  final child1 = 'child-1';
  final child2 = 'child-2';
  final standalone = 'standalone';
  
  await db.createCase(CasesCompanion(id: Value(groupId), isGroup: Value(true)));
  await db.createCase(CasesCompanion(id: Value(child1), parentCaseId: Value(groupId)));
  await db.createCase(CasesCompanion(id: Value(child2), parentCaseId: Value(groupId)));
  await db.createCase(CasesCompanion(id: Value(standalone))); // Root case
  
  final children = await db.getChildCases(groupId);
  expect(children.length, 2);
  expect(children.map((c) => c.id), containsAll([child1, child2]));
});

test('getCaseHierarchyPath builds correct path', () async {
  final groupId = 'group-1';
  final childId = 'child-1';
  
  await db.createCase(CasesCompanion(
    id: Value(groupId),
    name: Value('Group'),
    isGroup: Value(true),
  ));
  await db.createCase(CasesCompanion(
    id: Value(childId),
    name: Value('Child'),
    parentCaseId: Value(groupId),
  ));
  
  final path = await db.getCaseHierarchyPath(childId);
  expect(path.length, 2);
  expect(path[0].id, groupId); // Parent first
  expect(path[1].id, childId); // Child second
});
```

---

## 9. Backward Compatibility

### 9.1 Existing Code Compatibility

**Case Creation (Old Code):**
```dart
// Phase 13-20 code (still works):
await database.createCase(
  CasesCompanion(
    id: Value(id),
    name: Value(name),
    status: Value('active'),
    // parentCaseId: not specified → NULL
    // isGroup: not specified → FALSE
  ),
);
```
✅ **Works:** Defaults applied automatically

**Case Queries (Old Code):**
```dart
// Existing queries still work:
final cases = await database.getAllCases(); // Returns all (flat)
final caseData = await database.getCase(id); // Returns with new fields
final pages = await database.getPagesByCase(id); // Unchanged
```
✅ **Works:** New fields included but ignored by old code

**Export Service (Old Code):**
```dart
// Phase 20 export still works:
final filePath = await ExportService.exportPDF(
  caseName: caseData.name,
  imagePaths: imagePaths,
);
```
✅ **Works:** No changes to export logic

### 9.2 Generated Code

**database.g.dart Changes:**
```dart
// Generated Case class will include new fields:
class Case {
  final String id;
  final String name;
  final String? description;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String ownerUserId;
  final String? parentCaseId; // NEW
  final bool isGroup;          // NEW
  
  // Constructor, copyWith, toCompanion all updated
}
```

**Companion Class:**
```dart
class CasesCompanion {
  final Value<String> id;
  final Value<String> name;
  // ... existing fields
  final Value<String?> parentCaseId; // NEW
  final Value<bool> isGroup;          // NEW
}
```

**Backward Compatibility:**
- Old code using `CasesCompanion` must be updated (build error)
- Or use `Value.absent()` for new fields
- Or rely on defaults (NULL/FALSE)

---

## 10. Risk Assessment Summary

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Migration Failure** | Very Low | High | SQLite atomic transactions |
| **Data Loss** | Very Low | Critical | Additive schema only |
| **Existing Code Breaks** | Low | Medium | Nullable + defaults |
| **Orphaned Cases** | Low | Low | Query-time filtering |
| **Circular References** | Zero | High | 1-level constraint + validation |
| **Group Gets Pages** | Medium | Low | Guard logic + UI disable |
| **Performance Degradation** | Low | Low | Indexed queries (future) |

**Overall Risk:** **LOW** ✅

**Recommendation:** Proceed with implementation in phases (21.1 → 21.2 → 21.3)

---

## 11. Next Steps

### 11.1 Immediate Actions (Phase 21.1)

**Do Now:**
1. ✅ Update `Cases` table schema (database.dart)
2. ✅ Add migration logic (v3 → v4)
3. ✅ Run build_runner to generate code
4. ✅ Test migration on device
5. ✅ Verify existing functionality unchanged

**Estimated Time:** 1-2 hours

---

### 11.2 Follow-Up Actions (Phase 21.2)

**Do Next:**
1. ✅ Add hierarchy query methods to AppDatabase
2. ✅ Add guard helper methods
3. ✅ Test queries manually (no UI)
4. ✅ Write unit tests for queries

**Estimated Time:** 2-3 hours

---

### 11.3 Guard Integration (Phase 21.3)

**Do Later:**
1. ✅ Create validation classes
2. ✅ Create guard classes
3. ✅ Integrate into existing services
4. ✅ Test guard behavior
5. ✅ Update Quick Scan to check `canScanCase()`
6. ✅ Update Export to check `canExportCase()`

**Estimated Time:** 3-4 hours

---

### 11.4 UI Integration (Phase 21.4 - FUTURE)

**Do Much Later (Separate Phase):**
1. ⏸️ Design group case UI
2. ⏸️ Update Home screen layout
3. ⏸️ Add group management actions
4. ⏸️ Update navigation
5. ⏸️ Test user flows

**Estimated Time:** 8-12 hours (full UI overhaul)

---

## 12. Questions for Clarification

Before implementation, please confirm:

### 12.1 Schema Design

1. **Column Names:** OK with `parentCaseId` and `isGroup`? Or prefer different names?
   - Alternative: `groupId`, `isFolder`, `parentId`

2. **Defaults:** OK with `isGroup=FALSE` by default?
   - All existing cases become regular cases (can scan/export)

3. **Foreign Key:** Should we enforce FK constraint in SQLite?
   - Recommendation: No (flexibility), but guard logic validates

### 12.2 Business Rules

4. **Group Case Delete:** Require empty or cascade delete children?
   - Option A: Prevent delete if children exist (safer)
   - Option B: Cascade delete all children (convenient)
   - Option C: Move children to root (orphan)

5. **Group Case Scan:** Should groups **ever** allow pages?
   - Current design: No pages on groups
   - Alternative: Allow but hide/ignore pages

6. **Child Case Limit:** Max children per group?
   - No limit? Or cap at 50/100?

### 12.3 Migration

7. **Test Data:** Do you have production data that needs migration?
   - If yes: Need backup strategy
   - If no: Can test freely

8. **Rollback:** Need automatic rollback if migration fails?
   - Current design: Rely on SQLite atomicity
   - Alternative: Custom rollback logic

---

## 13. Summary

**Phase 21 Goal:** Add 1-level case hierarchy (Group Cases)

**Schema Changes:**
- ✅ Add `parentCaseId` (nullable TEXT)
- ✅ Add `isGroup` (boolean, default FALSE)
- ✅ Migration v3 → v4 (safe, additive)

**Business Rules:**
- ✅ Group Cases: Cannot scan, cannot export, can contain child cases
- ✅ Regular Cases: Can scan, can export, cannot contain children
- ✅ Max depth: 1 level (no nested groups)

**Implementation Strategy:**
1. **Phase 21.1:** Schema + Migration (data layer only)
2. **Phase 21.2:** Hierarchy API (service layer)
3. **Phase 21.3:** Guard Logic (business rules)
4. **Phase 21.4:** UI Integration (future, separate phase)

**Risk Level:** LOW ✅
- Additive schema changes
- Backward compatible
- No data loss
- Existing functionality preserved

**Ready to implement:** YES (pending confirmation of questions above)

---

**Report Prepared By:** GitHub Copilot (Claude Sonnet 4.5)  
**Feature:** Case Hierarchy (1-Level)  
**Status:** Design Complete, Awaiting Approval  
**Last Updated:** January 10, 2026
