# Phase 14 – Case Detail Replacement Report

## 1. New Case Detail UI
- Screen: `lib/src/features/case/case_detail_screen.dart`
- Layout: AppBar (case name + PDF export), grid of page cards (thumbnails), actions per page
- Page actions: View (full image dialog), Rename (inline dialog), Delete (confirm + file delete)
- Refresh: Pull-to-refresh reloads case + pages via Riverpod providers
- Empty state: Shows case name and "No pages yet" with neutral copy

## 2. Legacy components removed
- Legacy case detail (`tap_detail_screen.dart`) no longer reachable; /tap route redirects to Home
- Removed lock/manifest/finalize and all vehicle terms from new screen
- No legacy zip export, no manifest usage, no license plate filters

## 3. Export behavior
- Enabled: Simple PDF export (per case) from current pages using `pdf` package (in-screen implementation)
- Disabled/Not used: legacy `zip_folder`, legacy manifest-driven export, legacy audit hooks
- Export flow: builds PDF from existing page image paths; saves to app documents (`case_<id>_export.pdf`); shows SnackBar on success/failure

## 4. Explicitly NOT changed
- Scan engine (VisionKit) untouched
- Database schema untouched (uses existing Cases/Pages tables)
- Quick Scan flow unchanged; QSCan case now opens new detail screen
- No folder logic added; no AI/OCR; no new navigation branches beyond /case/:caseId

## 5. Known limitations
- PDF export uses raw page image paths; if files were temp or deleted, export may skip missing pages
- No page reorder or folder organization yet
- No sharing UI for the generated PDF (file saved locally only)
- Case creation still TODO in Home (button shows toast + refresh)
- Smoke test on device not yet run for this screen (structure compiled clean)
