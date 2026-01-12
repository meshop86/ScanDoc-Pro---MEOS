# Phase 21: Manual Test Plan
**Date:** 2026-01-10  
**Purpose:** Verify bug fixes + system stability  
**Scope:** UUID v4 IDs, Ghost file cleanup, Hierarchy constraints

---

## Prerequisites

### Test Environment
- ✅ Device: iPhone 17 Pro (Simulator)
- ✅ Build: Release mode, no codesign
- ✅ Flutter: Latest stable
- ✅ Fresh install (clear all data)

### Test Data Checklist
- [ ] Sample images ready (5-10 JPG/PNG)
- [ ] Device storage monitor open (Settings > General > iPhone Storage)
- [ ] Console log visible (for print statements)

---

## Test Suite 1: UUID ID Generation (Bug Fix 1)

**Objective:** Verify no UNIQUE constraint errors with UUID v4

### TEST 1.1: Rapid Case Creation
**Steps:**
1. Tap "Tạo Case" 10 times quickly (< 5 seconds)
2. Wait for all cases to appear
3. Check DB via console logs

**Expected Results:**
- ✅ All 10 cases created successfully
- ✅ No UNIQUE constraint errors
- ✅ All case IDs are different UUIDs (36 chars, format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`)

**Verification:**
```
Console should show:
✅ Created case: 550e8400-e29b-41d4-a716-446655440000
✅ Created case: 6ba7b810-9dad-11d1-80b4-00c04fd430c8
✅ Created case: 9b3e3f7a-8c5d-4f2e-9e1a-7d8c9b4e5f6a
...

FAIL indicators:
❌ UNIQUE constraint failed: cases.id
❌ Duplicate case IDs
❌ App crash
```

**Pass/Fail:** _________

---

### TEST 1.2: Rapid Page Scan (Quick Scan)
**Steps:**
1. Launch Quick Scan
2. Scan 20 images quickly (tap shutter repeatedly)
3. Confirm → Go to case detail
4. Verify all 20 pages visible

**Expected Results:**
- ✅ All 20 pages recorded in DB
- ✅ No duplicate page IDs
- ✅ All pages show correct images
- ✅ No UNIQUE constraint errors

**Verification:**
```
Console should show:
✅ Created page: 7c9e6679-7425-40de-944b-e07fc1f90ae7
✅ Created page: 3d813cbb-47fb-4129-a0cc-00185b0f0c08
...

Page grid shows: 20 thumbnails
```

**Pass/Fail:** _________

---

### TEST 1.3: Simultaneous Export
**Steps:**
1. Open case with 10+ pages
2. Export as PDF → Don't wait
3. Immediately export as ZIP (before PDF finishes)
4. Wait for both to complete

**Expected Results:**
- ✅ Both exports succeed
- ✅ No duplicate export IDs
- ✅ Both files created on disk
- ✅ Export list shows 2 items

**Verification:**
```
Console should show:
✅ Created export: pdf_550e8400-e29b-41d4-a716-446655440000
✅ Created export: zip_6ba7b810-9dad-11d1-80b4-00c04fd430c8

FAIL indicators:
❌ UNIQUE constraint failed: exports.id
❌ One export missing
```

**Pass/Fail:** _________

---

### TEST 1.4: Stress Test (Create 100 Cases)
**Steps:**
1. Write quick script or tap "Tạo Case" 100 times
2. Wait for completion
3. Count cases in list

**Expected Results:**
- ✅ Exactly 100 cases created
- ✅ Zero UNIQUE errors
- ✅ App remains stable

**Optional Script:**
```dart
// In developer console or test file
for (int i = 0; i < 100; i++) {
  await database.createCase(
    CasesCompanion(
      id: Value(const Uuid().v4()),
      name: Value('Stress Test $i'),
      createdAt: Value(DateTime.now()),
    ),
  );
}
```

**Pass/Fail:** _________

---

## Test Suite 2: Ghost File Cleanup (Bug Fix 2)

**Objective:** Verify complete file deletion + no ghost pages

### TEST 2.1: Clean Case Deletion
**Steps:**
1. Note initial storage usage (Settings > Storage)
2. Create case "Test Delete"
3. Scan 5 pages (~2-5 MB images)
4. Export as PDF (~1 MB)
5. Export as ZIP (~1-3 MB)
6. Note storage after exports
7. Delete case
8. Wait 10 seconds
9. Check storage again

**Expected Results:**
- ✅ All page image files deleted
- ✅ All page thumbnail files deleted
- ✅ PDF export file deleted
- ✅ ZIP export file deleted
- ✅ Storage returned to initial value (±10%)

**Storage Math:**
```
Initial:  1.2 GB used
After create + scan: 1.205 GB (+5 MB)
After exports: 1.209 GB (+4 MB)
After delete: 1.2 GB (back to initial) ✅

FAIL if storage remains at 1.209 GB ❌
```

**Console Verification:**
```
✅ Deleted 5 page(s)
✅ Deleted export file: test_delete.pdf
✅ Deleted export file: test_delete.zip
✅ Deleted 2 export(s)
✅ Deleted 0 folder(s)
✅ Deleted case: Test Delete
```

**Pass/Fail:** _________

---

### TEST 2.2: Ghost Page Prevention (Critical Test)
**User Scenario:** "Xoá toàn bộ case → tạo mới → phải EMPTY tuyệt đối"

**Steps:**
1. Create 3 cases, each with 3 pages
2. Note total: 9 pages, 9 images
3. Delete all 3 cases (swipe to delete)
4. Verify home screen empty
5. Create NEW case "Fresh Start"
6. Open case detail
7. **CRITICAL:** Page grid must be EMPTY

**Expected Results:**
- ✅ Home screen shows 0 cases after delete
- ✅ New case "Fresh Start" created
- ✅ Case Detail shows: "No pages yet" empty state
- ✅ NO pages from deleted cases shown
- ✅ Console shows NO ghost page warnings

**FAIL Indicators:**
```
❌ Page grid shows old pages
❌ Console: ⚠️ Skipping ghost page: xxx (file not found)
❌ Case Detail shows 3, 6, or 9 pages
```

**Pass/Fail:** _________

---

### TEST 2.3: Provider Reload After Manual Delete
**Simulate DB corruption:**

**Steps:**
1. Create case, scan 3 pages
2. Open Case Detail (see 3 pages)
3. **Simulate corruption:** Manually delete image files via Xcode/Files app
   - Path: `Library/Application Support/[app]/images/`
4. Pull to refresh in Case Detail
5. Verify empty state

**Expected Results:**
- ✅ Pages disappear from grid
- ✅ Empty state shown: "No pages yet"
- ✅ Console shows: `⚠️ Skipping ghost page: xxx`
- ✅ No crash

**This tests:** Provider filter logic (case_providers.dart lines 22-29)

**Pass/Fail:** _________

---

### TEST 2.4: Verify DeleteGuard Usage
**Ensure UI uses DeleteGuard, not custom logic**

**Steps:**
1. Delete case from Home Screen
2. Check console logs

**Expected Console Output:**
```
✅ Deleted X page(s)
✅ Deleted export file: [filename]
✅ Deleted Y export(s)
✅ Deleted Z folder(s)
✅ Deleted case: [case name]
```

**If you see custom delete logic, FAIL:**
```
❌ "Deleted X image files" (old Phase 19 logic)
❌ No export file deletion logs
❌ Missing cascade delete logs
```

**Pass/Fail:** _________

---

## Test Suite 3: Case Hierarchy Constraints

**Objective:** Verify Phase 21 hierarchy rules

### TEST 3.1: Group Case Constraints
**Steps:**
1. Create Group case "Group A"
2. Try to scan from Group A
3. Try to export from Group A
4. Check pages count

**Expected Results:**
- ✅ Scan button DISABLED or hidden
- ✅ Export button DISABLED or hidden
- ✅ Pages count always = 0
- ✅ Console: `canScanCase(Group A) = false`

**Pass/Fail:** _________

---

### TEST 3.2: Delete Empty Group
**Steps:**
1. Create Group case "Empty Group"
2. Verify no child cases
3. Delete "Empty Group"

**Expected Results:**
- ✅ Delete succeeds
- ✅ Console: `✅ Deleted empty group case: Empty Group`

**Pass/Fail:** _________

---

### TEST 3.3: Delete Non-Empty Group (Guard)
**Steps:**
1. Create Group case "Parent"
2. Create child case under "Parent"
3. Try to delete "Parent"

**Expected Results:**
- ❌ Delete FAILS with error
- ✅ Error message: "Cannot delete group: contains 1 case(s). Move or delete child cases first."
- ✅ Group still exists after attempt

**Console Verification:**
```
Exception: Cannot delete group: contains 1 case(s). Move or delete child cases first.
```

**Pass/Fail:** _________

---

### TEST 3.4: Hierarchy Path (Breadcrumbs)
**Steps:**
1. Create Group "Documents"
2. Create child case "Invoice 001" under "Documents"
3. Open "Invoice 001"
4. Check navigation bar / breadcrumb

**Expected Results:**
- ✅ Path shows: `Documents > Invoice 001`
- ✅ Can tap "Documents" to go back
- ✅ `getCaseHierarchyPath()` returns 2 cases

**Console Verification:**
```
Hierarchy path: [Group: Documents, Case: Invoice 001]
```

**Pass/Fail:** _________

---

## Test Suite 4: Edge Cases & Stress

### TEST 4.1: Rapid Delete-Create Cycle
**Steps:**
1. Create case "A"
2. Delete case "A"
3. Immediately create case "B"
4. Repeat 20 times

**Expected Results:**
- ✅ No crashes
- ✅ No ghost data
- ✅ Each new case is truly empty

**Pass/Fail:** _________

---

### TEST 4.2: Network Interruption (If Cloud Sync)
**N/A - No cloud sync yet**

**Pass/Fail:** _________

---

### TEST 4.3: Low Storage Warning
**Steps:**
1. Fill device storage to < 1 GB free
2. Try to scan 100 pages

**Expected Results:**
- ✅ Graceful error: "Storage full"
- ✅ No partial data (all-or-nothing)
- ✅ No corrupted files

**Pass/Fail:** _________

---

## Test Suite 5: Data Integrity

### TEST 5.1: UUID Format Validation
**Steps:**
1. Create 10 cases
2. Export DB (via Flutter DevTools or Drift Inspector)
3. Check `cases.id` column

**Expected Format:**
```
550e8400-e29b-41d4-a716-446655440000
6ba7b810-9dad-11d1-80b4-00c04fd430c8
```

**FAIL Format:**
```
case_1736524800000 (old timestamp)
```

**Pass/Fail:** _________

---

### TEST 5.2: Foreign Key Integrity
**Steps:**
1. Create case + 5 pages
2. Note page IDs in DB
3. Delete case
4. Check `pages` table

**Expected Results:**
- ✅ All 5 pages deleted (CASCADE)
- ✅ No orphan pages in DB
- ✅ Image files deleted from disk

**Pass/Fail:** _________

---

### TEST 5.3: Concurrent Operations
**Steps:**
1. Open 2 Case Detail screens (if possible, or rapid switching)
2. Delete case from Home while viewing Case Detail
3. Check Case Detail behavior

**Expected Results:**
- ✅ Case Detail shows error or navigates back
- ✅ No crash
- ✅ No stale data

**Pass/Fail:** _________

---

## Summary Checklist

### Critical Tests (Must Pass)
- [ ] TEST 1.1: Rapid Case Creation (UUID)
- [ ] TEST 1.2: Rapid Page Scan (UUID)
- [ ] TEST 2.1: Clean Case Deletion (Storage)
- [ ] TEST 2.2: Ghost Page Prevention (**USER SCENARIO**)
- [ ] TEST 3.3: Delete Non-Empty Group (Guard)

### Important Tests
- [ ] TEST 1.3: Simultaneous Export
- [ ] TEST 2.3: Provider Reload
- [ ] TEST 2.4: DeleteGuard Usage
- [ ] TEST 3.1: Group Constraints
- [ ] TEST 3.4: Hierarchy Path

### Nice-to-Have Tests
- [ ] TEST 1.4: Stress (100 cases)
- [ ] TEST 4.1: Delete-Create Cycle
- [ ] TEST 5.1: UUID Format
- [ ] TEST 5.2: Foreign Key Integrity

---

## Test Results Summary

**Date Tested:** __________  
**Tester:** __________  
**Device:** iPhone 17 Pro  
**Build:** Release (no codesign)

| Test Suite | Pass | Fail | Notes |
|------------|------|------|-------|
| 1. UUID Generation | ___ | ___ | |
| 2. Ghost File Cleanup | ___ | ___ | |
| 3. Hierarchy Constraints | ___ | ___ | |
| 4. Edge Cases | ___ | ___ | |
| 5. Data Integrity | ___ | ___ | |

**Overall Status:** ⬜ PASS / ⬜ FAIL

**Blockers Found:**
1. _________________________________________
2. _________________________________________

**Sign-off:**
- [ ] All critical tests passed
- [ ] No data corruption observed
- [ ] Storage cleanup verified
- [ ] Ready for Phase 21.4 (UI Hierarchy)

---

**Next Steps:**
1. If all tests PASS → Proceed to Phase 21.4 Planning
2. If any test FAILS → Fix bug, re-test affected suite
3. Document any new edge cases found

---

**Test Plan Version:** 1.0  
**Last Updated:** 2026-01-10
