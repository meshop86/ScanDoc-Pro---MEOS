# Phase 21: Test Execution Guide
**Date:** 2026-01-10  
**Tester:** Manual + Automated Support  
**Device:** iPhone 17 Pro Simulator  
**Status:** 🟡 IN PROGRESS

---

## Pre-Test Setup

### ✅ Environment Check
- [x] App launched on simulator
- [ ] Console logs visible
- [ ] Storage monitor ready
- [ ] Test data prepared

### 🗑️ Clean Slate
**IMPORTANT:** Clear all existing data before testing

```bash
# Method 1: Reset simulator
xcrun simctl erase EC5951AE-6BAD-4F2A-AA3E-2EB442C6A1A4

# Method 2: Delete app data
# Settings > General > iPhone Storage > ScanDoc Pro > Delete App
```

**Verification:**
- [ ] App shows empty home screen
- [ ] No existing cases
- [ ] Fresh install state

---

## Test Suite 1: UUID ID Generation

### TEST 1.1: Rapid Case Creation ⏱️ 5 seconds
**CRITICAL TEST - MUST PASS**

**Manual Steps:**
1. Open app (home screen)
2. Tap "Tạo Case" button 10 times as fast as possible (< 5 sec)
3. Each tap: Enter name "Test 1", "Test 2", etc. → Save

**What to Observe:**
- ✅ All 10 cases appear in list
- ✅ No crash or error dialog
- ✅ Console shows no UNIQUE constraint errors

**Console Success Pattern:**
```
✅ Created case: 550e8400-e29b-41d4-a716-446655440000
✅ Created case: 6ba7b810-9dad-11d1-80b4-00c04fd430c8
...
```

**Console FAIL Pattern:**
```
❌ UNIQUE constraint failed: cases.id
❌ SqliteException: UNIQUE constraint
```

**Result:** [ ] PASS / [ ] FAIL

**Notes:**
_____________________________________________

---

### TEST 1.2: Rapid Page Scan 📸 20 images
**CRITICAL TEST - MUST PASS**

**Manual Steps:**
1. Launch Quick Scan (from home or bottom nav)
2. Grant camera permission if prompted
3. Point camera at ANY surface (paper, wall, etc.)
4. Tap shutter button 20 times rapidly
5. Tap "Confirm" → Go to case detail

**What to Observe:**
- ✅ Case created with name "QScan_..."
- ✅ Case detail shows 20 pages in grid
- ✅ No missing pages
- ✅ No duplicate page errors

**Console Success Pattern:**
```
✅ Created page: 7c9e6679-7425-40de-944b-e07fc1f90ae7
✅ Created page: 3d813cbb-47fb-4129-a0cc-00185b0f0c08
...
(20 unique UUIDs)
```

**Result:** [ ] PASS / [ ] FAIL

**Notes:**
_____________________________________________

---

### TEST 1.3: Simultaneous Export 📦 PDF + ZIP
**Important Test**

**Manual Steps:**
1. Open case with 10+ pages
2. Tap "Export PDF" → Don't wait
3. **Immediately** tap "Export ZIP" (before PDF finishes)
4. Wait for both progress bars to complete

**What to Observe:**
- ✅ Both exports succeed
- ✅ Export list shows 2 items (PDF + ZIP)
- ✅ Both files exist (check Files app)
- ✅ No UNIQUE constraint error

**Console Success Pattern:**
```
✅ Created export: 550e8400-e29b-41d4-a716-446655440000 (PDF)
✅ Created export: 6ba7b810-9dad-11d1-80b4-00c04fd430c8 (ZIP)
```

**Result:** [ ] PASS / [ ] FAIL

**Notes:**
_____________________________________________

---

## Test Suite 2: Ghost File Cleanup

### TEST 2.1: Clean Case Deletion 💾 Storage Check
**CRITICAL TEST - MUST PASS**

**Manual Steps:**
1. Open Settings > General > iPhone Storage
2. Find "ScanDoc Pro" → Note storage (e.g., 1.2 GB)
3. In app: Create case "Storage Test"
4. Scan 5 pages (large images ~1 MB each)
5. Export as PDF
6. Export as ZIP
7. Check storage again (should be ~+7-10 MB)
8. Delete case "Storage Test"
9. Wait 10 seconds
10. Check storage again

**What to Observe:**
- ✅ Storage returns to initial value (±10%)
- ✅ Console shows file deletion logs

**Storage Math Example:**
```
Initial:  1.2 GB
After:    1.21 GB (+10 MB)
Delete:   1.2 GB (back to initial) ✅

FAIL if: 1.21 GB (leaked) ❌
```

**Console Success Pattern:**
```
✅ Deleted 5 page(s)
✅ Deleted export file: storage_test.pdf
✅ Deleted export file: storage_test.zip
✅ Deleted 2 export(s)
✅ Deleted case: Storage Test
```

**Result:** [ ] PASS / [ ] FAIL

**Notes:**
_____________________________________________

---

### TEST 2.2: Ghost Page Prevention 👻
**CRITICAL TEST - USER SCENARIO - MUST PASS**

**Manual Steps:**
1. Create case "Ghost A", scan 3 pages
2. Create case "Ghost B", scan 3 pages
3. Create case "Ghost C", scan 3 pages
4. Verify: 3 cases, 9 total pages
5. **Delete ALL 3 cases** (swipe left → delete each)
6. Verify home screen is EMPTY
7. Create NEW case "Fresh Start"
8. Open "Fresh Start" case detail
9. **CRITICAL CHECK:** Page grid must be EMPTY

**What to Observe:**
- ✅ Home screen shows 0 cases after delete
- ✅ "Fresh Start" case detail shows: "No pages yet"
- ✅ NO pages from deleted cases
- ✅ NO console warnings about ghost pages

**Console FAIL Pattern:**
```
❌ ⚠️ Skipping ghost page: xxx (file not found)
```

**Result:** [ ] PASS / [ ] FAIL

**This is THE most important test per user request!**

**Notes:**
_____________________________________________

---

### TEST 2.3: Provider Reload 🔄 Ghost Detection
**Important Test**

**Manual Steps:**
1. Create case, scan 3 pages
2. Open case detail (see 3 pages)
3. Keep app open
4. **Via Xcode or Finder:**
   - Navigate to: `~/Library/Developer/CoreSimulator/Devices/EC5951AE-6BAD-4F2A-AA3E-2EB442C6A1A4/data/Containers/Data/Application/[app]/Library/Application Support/[appname]/images/`
   - Delete 2 of the 3 image files manually
5. Return to app
6. Pull down to refresh (or navigate away and back)

**What to Observe:**
- ✅ Only 1 page shown (the one with valid file)
- ✅ Console: `⚠️ Skipping ghost page: xxx`
- ✅ No crash

**Result:** [ ] PASS / [ ] FAIL

**Notes:**
_____________________________________________

---

### TEST 2.4: DeleteGuard Usage ✅ Verify Logic
**Important Test**

**Manual Steps:**
1. Create case with pages
2. Delete case from home screen
3. **Check console logs**

**What to Observe:**
- ✅ Console shows DeleteGuard messages (not old Phase 19 logic)

**Console Success Pattern:**
```
✅ Deleted X page(s)
✅ Deleted export file: [filename]
✅ Deleted Y export(s)
✅ Deleted case: [name]
```

**Console FAIL Pattern (old logic):**
```
❌ "Deleted X image files" (Phase 19 custom logic)
❌ Missing export file deletion
```

**Result:** [ ] PASS / [ ] FAIL

**Notes:**
_____________________________________________

---

## Test Suite 3: Case Hierarchy Constraints

### TEST 3.1: Group Case Constraints 🚫 No Scan/Export
**Critical for Phase 21**

**Manual Steps:**
1. Create Group case "Test Group" (if UI supports)
   - **NOTE:** If "Create Group" UI not implemented yet, SKIP this test
2. Open group detail
3. Look for Scan button
4. Look for Export buttons

**What to Observe:**
- ✅ Scan button: DISABLED or HIDDEN
- ✅ Export buttons: DISABLED or HIDDEN
- ✅ Pages count = 0 always

**Result:** [ ] PASS / [ ] FAIL / [ ] SKIP (UI not ready)

**Notes:**
_____________________________________________

---

### TEST 3.2: Delete Empty Group ✅ Should Succeed
**Critical for Phase 21**

**Manual Steps:**
1. Create Group case "Empty Group"
2. Verify no child cases
3. Delete "Empty Group"

**What to Observe:**
- ✅ Delete succeeds
- ✅ Console: `✅ Deleted empty group case: Empty Group`

**Result:** [ ] PASS / [ ] FAIL / [ ] SKIP (UI not ready)

**Notes:**
_____________________________________________

---

### TEST 3.3: Delete Non-Empty Group ❌ Must Block
**CRITICAL TEST - MUST PASS**

**Manual Steps:**
1. Create Group case "Parent"
2. Create child case under "Parent"
3. Try to delete "Parent" group

**What to Observe:**
- ❌ Delete FAILS
- ✅ Error dialog: "Cannot delete group: contains 1 case(s)"
- ✅ Group still exists

**Console Success Pattern:**
```
Exception: Cannot delete group: contains 1 case(s). Move or delete child cases first.
```

**Result:** [ ] PASS / [ ] FAIL / [ ] SKIP (UI not ready)

**Notes:**
_____________________________________________

---

## Test Summary

### Critical Tests (MUST PASS before Phase 21.4)
| Test ID | Name | Status | Notes |
|---------|------|--------|-------|
| 1.1 | Rapid Case Creation | [ ] | UUID collision test |
| 1.2 | Rapid Page Scan | [ ] | UUID collision test |
| 2.1 | Storage Cleanup | [ ] | File deletion verification |
| 2.2 | **Ghost Page Prevention** | [ ] | **USER SCENARIO** |
| 2.4 | DeleteGuard Usage | [ ] | Architecture check |
| 3.3 | Delete Non-Empty Group | [ ] | Guard enforcement |

### Important Tests (Should Pass)
| Test ID | Name | Status | Notes |
|---------|------|--------|-------|
| 1.3 | Simultaneous Export | [ ] | |
| 2.3 | Provider Reload | [ ] | |
| 3.1 | Group Constraints | [ ] | May skip if UI not ready |
| 3.2 | Delete Empty Group | [ ] | May skip if UI not ready |

---

## Issues Found

### Issue 1: [Title]
**Test:** [Test ID]  
**Severity:** [ ] Critical / [ ] Major / [ ] Minor  
**Description:**

**Expected:**

**Actual:**

**Proposed Fix:**

---

### Issue 2: [Title]
**Test:** [Test ID]  
**Severity:** [ ] Critical / [ ] Major / [ ] Minor  
**Description:**

**Expected:**

**Actual:**

**Proposed Fix:**

---

## Final Decision

### ✅ ALL CRITICAL TESTS PASSED
- [ ] Ready to proceed to Phase 21.4 UI implementation
- [ ] Sign-off by: _______________

### ❌ SOME TESTS FAILED
- [ ] Fix bugs first
- [ ] Re-run failed tests
- [ ] Do NOT start Phase 21.4 until all critical pass

---

## Next Steps

**If PASS:**
1. Review Phase21_4_UI_Hierarchy_Planning.md
2. Start Phase 21.4A (Home Screen group list)
3. Implement incrementally

**If FAIL:**
1. Document issues above
2. Fix bugs
3. Re-run affected test suites
4. Update this document with re-test results

---

**Test Session Started:** _____________  
**Test Session Completed:** _____________  
**Total Duration:** _____________  
**Tester Signature:** _____________
