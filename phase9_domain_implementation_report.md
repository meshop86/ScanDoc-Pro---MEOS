# Phase 9 – Domain Generalization Implementation

## Model changes (ScanDoc Pro)
- **Case** (Tập hồ sơ): renamed from vehicle-specific context to generic document container; preserves all TAP semantics (status, audit, lock/export).
- **Document Set** (Bộ giấy tờ): generalized from bien_so (vehicle plate); user provides display name; stored with slug-based folder naming.
- **Page**: individual scanned images; ordering preserved per Document Set.
- Audit: extended with optional `case_name` and `document_set` metadata; existing event types and semantics unchanged.

## Storage & naming rules (Phase 9 implementation)
- Root folder: `/HoSoXe/` (unchanged for backward compatibility).
- Path structure: `HoSoXe/<caseId>/<documentSetSlug>/` (generalized from `/HoSoXe/<bienSo>/`).
- Image filenames:
  - Single page: `<documentSetSlug>.jpg`
  - Multi-page: `<documentSetSlug>_p<n>.jpg`
- Legacy format support: app still reads old `<docType>_<bienSo>_p<n>.jpg` files via DocumentSetService helpers.

## Backward compatibility
- **Read path**: manifest.json lookup on old bien_so field; DocumentSetService.isLegacyFormat() detects v1.x data; regex parsers accept both old/new naming.
- **Write path**: new manifests include both legacy `bien_so` and new `case_name`/`document_set_slug`/`document_set_display_name` fields; existing data untouched.
- **Slug generation**: auto-convert display name to slug on create; slug stored in manifest for consistent internal naming.

## Code changes (Phase 9 deployed)
1. **DocumentSetService** (new file): 
   - `toSlug()`: convert display name → slug.
   - `isLegacyFormat()`: detect old bien_so vs new slug.
   - `getDocumentSetDirectory()`: unified path builder supporting both legacy/new.
   - `buildPageFilename()`, `parsePageNumber()`: unified file naming.
   - `listDocumentPages()`, `deletePage()`, `deleteDocumentSet()`, `renameDocumentSet()`: generalized ops.

2. **ManifestService** (extended):
   - manifest.json now includes:
     - Legacy: `bien_so`
     - New: `case_name`, `document_set_display_name`, `document_set_slug`
   - All doc parsing unchanged; slug auto-computed from bien_so on legacy data.

3. **AuditService** (extended):
   - `logAction()` signature: added optional `caseName` and `documentSetName` params.
   - New fields in audit log: `case_name`, `document_set` (if provided).
   - Existing events unaffected; backward compatible.

## Migration notes (v1.x → Phase 9)
- No data migration run; app reads legacy folders as-is.
- UI remains vehicle-centric in Phase 9 (naming still shows biển số internally).
- Phase 10+ will update UI labels and manifest writing to use Document Set terminology.
- Quota, zip, pdf engines unmodified; they consume legacy bien_so from manifest without change.

## Testing scope (Phase 9)
- Legacy data: manifest reads old bien_so correctly; audit still works.
- DocumentSetService: slug generation, page listing, file naming on new data paths.
- No UI test yet; backend compatibility layer complete.

## Readiness
- Phase 9 implementation complete; app compiles and backward-compatible with v1.x data.
- Phase 10 (UI/UX Generalization) will flip language and references to Document Set terminology.
