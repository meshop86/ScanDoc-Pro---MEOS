# Phase 12.3 – UI Polish & UX Correction (Safe Mode)

## Scope & Guardrails
- UI/layout/styling only. No services, logic, models, or navigation touched.
- Frozen files untouched: scan_page.dart, vision_scan_service.dart, zip_service.dart, pdf_service.dart, audit_service.dart, native code.

## Screens Touched
1) Welcome / Entry (login_page.dart)
2) Case List (tap_manage_page.dart)
3) Case Detail (tap_page.dart)

## Improvements by Screen
### 1) Welcome / Entry
- Reframed as a welcome card with clear copy and accent avatar, prioritizing display-name input with autofocus and helper hint.
- PRO upgrade shown as compact, secondary tile; CTA spacing tightened.
- Theme change feedback now inline (top-safe) instead of bottom snackbar; language/theme actions remain top-right.
- Inline info banner slot keeps notifications from blocking the primary Continue button.

### 2) Notification UX (Global within touched screens)
- Replaced snackbars with top material banners for errors/success on list/detail pages; messages no longer obstruct CTAs.
- Login theme feedback uses inline notifier, avoiding snackbar overlap.

### 3) Case List
- Reduced filter-chip weight (light borders, subtle selection color) and improved horizontal spacing.
- Kept only one primary action: header “New Case” button; removed FAB to avoid dual CTAs.
- Maintained list hierarchy/spacing and empty-state clarity.

### 4) Case Detail
- Kept Quick Scan / Document Set CTA row intact.
- Manual entry form moved behind an “Advanced (manual entry)” toggle to declutter default view.
- Tags dropdowns collapsed into an ExpansionTile (hidden by default) to show only when relevant.
- Converted feedback to top banners to keep actions unobstructed; maintained empty-state guidance.

## Notes
- No flow or logic changes were introduced.
- Tests not run (UI-only changes).
