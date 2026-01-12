# Phase 12.4 – Legacy UI Purge (UI-Only)

## Screens Affected
- Case Detail (tap_page.dart)
- Shared label presets (label_model.dart)

## What Was Removed
- Plate-style manual entry pattern ("14 | code | number") replaced with free-text title entry.
- Vehicle/plate hints and examples removed from document set creation dialog.
- Vehicle/inspection-related labels removed from presets: Biển số, Chất lượng ảnh, Trạng thái kiểm tra.

## Confirmation
- No navigation, services, or engine code was modified.
- UI terminology is now document-centric: titles and tags only.
- No vehicle-related concepts remain in visible UI.

## Notes
- Tests not run (UI-only changes).
