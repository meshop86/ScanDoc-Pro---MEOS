# Phase 8 – ScanDoc Pro Generalization & UI/UX Modernization

## Domain model (new)
- Case (Tập hồ sơ): root container; holds multiple Document Sets; preserves audit/export states.
- Document Set (Bộ giấy tờ): user-defined name; groups related documents/pages inside a Case.
- Document/Page: individual scanned images belonging to a Document Set; retains ordering.

## Storage & naming rules
- User provides Document Set name; stored as folder-friendly slug while keeping display name in manifest.
- Image naming: `<documentSetSlug>_p<n>.jpg` for multi-page sets; `<documentSetSlug>.jpg` for single image.
- Single image set: store directly under Case/<docSet>/
- Multi-image set or multiple documents: use subfolder per Document Set; maintain page order.
- PDFs/Zips/Audit remain unchanged; manifests store display name + slug mapping; avoid breaking existing audit, zip, pdf logic.

## PDF export options
- Whole Case PDF: parent-child ordering by Document Set name then page number.
- Per-Document Set PDF: export selected set; order pages by page index; include set metadata in header.
- Respect existing guards (exported/admin override) and audit logging; do not alter engine semantics.

## UI/UX changes
- Login screen: language toggle (EN/VI) visible before auth; remember choice locally.
- Theme: Light/Dark supports system default plus manual override; fast toggle in settings/toolbar.
- Remove vehicle-specific labels/icons; use neutral document imagery and terminology (Case, Document Set, Page).
- Scanning flows optimized for batch: clear add-page CTA, reorder/delete per set, prominent Done/Save.
- List views: show Cases and nested Document Sets; surface counts (sets/pages) and last modified.
- Export dialog: allow Whole Case vs per Document Set selection; show expected file size/page count before export.
- Permissions: camera prompt copy updated to general document scanning.

## Migration notes (from vehicle-specific to general)
- Data folders: rename “HoSoXe” casing to neutral “Cases” while retaining backward compatibility via alias/symlink or dual-read.
- Manifest fields: deprecate `bien_so` and vehicle-specific labels; introduce `case_name`, `document_sets[]` with `display_name`, `slug`, `pages`.
- File names: accept old `<docType>_<bienSo>_p<n>.jpg`; new pattern uses `documentSetSlug`; maintain regex to parse both during transition.
- UI text: replace “biển số/hồ sơ xe” with “Case/Document Set/Page”; update tooltips, dialogs, and validation messages.
- Audit: keep event types; add metadata fields for `case_name` and `document_set` without changing event semantics.
- PDFs/Zips: support both legacy and new naming in manifest loading; output uses new naming but should read old for backward compatibility.
