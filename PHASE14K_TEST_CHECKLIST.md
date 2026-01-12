🎯 PHASE 14.K – LEGACY ROUTING KILL TEST CHECKLIST

DEVICE: iPhone (00008120-00043D3E14A0C01E)
BUILD: Phase 14.K (Legacy routes DELETED)
STATUS: App running now, ready for manual test

═════════════════════════════════════════════════════════════════

✅ TEST 1: HOME SCREEN LOADS CORRECTLY

[ ] Open app → Home tab shows "Case Library"
[ ] NO "Biển số" title
[ ] NO "Tờ khai" visible
[ ] Case cards display with case names
[ ] No vehicle terminology in UI

═════════════════════════════════════════════════════════════════

✅ TEST 2: TAP CASE CARD → NEW UI APPEARS

[ ] Tap any case → CaseDetailScreen opens
[ ] AppBar shows case name (e.g., "QSCan", "Case 001")
[ ] PDF export button visible in AppBar
[ ] Page grid displays (2 columns)
[ ] Page cards show thumbnails
[ ] NO "Biển số" in AppBar
[ ] NO "Tờ khai" in detail
[ ] NO "TAP_001" naming visible
[ ] NO old tap_detail_screen appears

═════════════════════════════════════════════════════════════════

✅ TEST 3: VIEW PAGE (Full-Screen Image)

[ ] Tap page thumbnail → full-screen image opens
[ ] Image displays correctly
[ ] Swipe/pinch to zoom works
[ ] Close button returns to case detail
[ ] NO vehicle terms in title
[ ] NO old UI overlays

═════════════════════════════════════════════════════════════════

✅ TEST 4: RENAME PAGE (Persistence Test)

[ ] In case detail, tap page → option menu
[ ] Select "Rename" → dialog appears
[ ] Enter new name (e.g., "Front Page")
[ ] Tap OK → name updates in grid
[ ] **KILL APP** (swipe up or disconnect)
[ ] **REOPEN APP** → navigate back to same case
[ ] [ ] Page name **MUST** be saved (shows "Front Page")
[ ] NO default naming like "Page 1"

═════════════════════════════════════════════════════════════════

✅ TEST 5: DELETE PAGE

[ ] In case detail, tap page → option menu
[ ] Select "Delete" → confirm dialog
[ ] Tap Delete → page disappears from grid
[ ] **KILL APP**
[ ] **REOPEN APP** → navigate back to case
[ ] Page **MUST** stay deleted
[ ] NO ghost cards, NO reappearing pages

═════════════════════════════════════════════════════════════════

✅ TEST 6: PDF EXPORT

[ ] In case detail AppBar → tap PDF icon
[ ] Select all pages (or leave default)
[ ] Tap "Export to Documents"
[ ] PDF saves (toast "Export successful")
[ ] Go to Files app
[ ] Find PDF in "Documents" folder
[ ] Open PDF → verify:
    [ ] All pages present
    [ ] Pages in correct order
    [ ] NO blank pages
    [ ] NO vehicle field templates
    [ ] NO "Tờ khai" headers

═════════════════════════════════════════════════════════════════

✅ TEST 7: SCAN → AUTO CREATE CASE

[ ] Tap "Scan" tab → Quick Scan screen
[ ] Tap "Start Scan" → VisionKit camera
[ ] Scan 3-5 pages
[ ] Complete scan → auto-save to "QSCan" case
[ ] Auto-navigate to Home
[ ] [ ] "QSCan" case appears in Case Library
[ ] Tap "QSCan" → NEW CaseDetailScreen opens
[ ] All scanned pages in grid ✓
[ ] NO old UI

═════════════════════════════════════════════════════════════════

✅ TEST 8: NO LEGACY SCREENS ACCESSIBLE

These should be IMPOSSIBLE to reach:

[ ] No way to trigger tap_detail_screen
[ ] No way to navigate to /tap route
[ ] No old home_screen.dart used
[ ] No "Biển số" / "Tờ khai" / "Nguồn gốc" text anywhere
[ ] Swipe/deep link attempts to /tap/xyz fail gracefully

═════════════════════════════════════════════════════════════════

📋 SCORING

Count PASS marks:

├─ All 8 sections PASS → ✅ **PHASE 14.K VERIFIED COMPLETE**
│
├─ 7 sections PASS → ⚠️ Minor issue, debug
│
└─ <7 sections PASS → ❌ **CRITICAL FAILURE, STOP**

═════════════════════════════════════════════════════════════════

🎖️ SUCCESS DEFINITION

PASS IF:
✅ Home screen shows Case Library (NEW UI)
✅ Tap case → CaseDetailScreen opens (NEW screen)
✅ Page grid, view, rename, delete all work
✅ PDF export creates valid PDF
✅ Scan workflow completes to new UI
✅ ZERO legacy screens visible
✅ ZERO old terminology ("Biển số", "Tờ khai")
✅ App never navigates to /tap or /bo routes

FAIL IF:
❌ Any "Biển số" text appears
❌ Any "Tờ khai" screen loads
❌ Old tap_detail_screen opens
❌ Routes.tap referenced anywhere
❌ /tap/:tapId route still exists

═════════════════════════════════════════════════════════════════

📝 NEXT STEPS AFTER TEST

IF ALL PASS:
→ Phase 14.K VERIFIED COMPLETE
→ Ready for Phase 13.3 (persistent image storage)

IF ANY FAIL:
→ REPORT immediately with:
   - Which test failed
   - What was expected
   - What actually happened
   - Screenshot if possible

═════════════════════════════════════════════════════════════════

Test Date: 7 Jan 2026
Tester: [Your Name]
Result: [ ] PASS / [ ] FAIL
Notes: ______________________________________

═════════════════════════════════════════════════════════════════
