# Phase 4 Output Engine Report

## ZIP v2 structure (final)
- Package root: HoSoXe/<tap_code>/
- Required artifacts: tap_manifest.json, audit_log.json, README.txt, each bien_so folder with JPG pages (original names preserved).
- README summarizes tap_code, status, created_at/by, system/user labels, bo_ho_so list, audit path, and document layout note.
- Validation: block ZIP if tap_manifest.json is missing/empty, any hồ sơ folder is missing, or no JPGs per hồ sơ. audit_log.json is ensured before zipping.
- Process order: prepare (ensure README + audit), validate (manifest + docs), then call native zip.

## PDF v1 rules (final)
- Scope: 1 PDF per hồ sơ (bien_so), generated from manifest documents.
- Page order: manifest.documents sorted by doc type name, pages follow manifest order (p1..pn); missing pages abort export.
- Header per page: tap_code, bien_so, created_at, created_by, labels.system, labels.user.
- Output path: HoSoXe/<tap_code>/<bien_so>/<bien_so>.pdf (or standalone without tap_code).

## Guards & admin override
- ZIP: require TAP status EXPORTED; adminOverride enables re-export and logs action EXPORT_ZIP_ADMIN_OVERRIDE.
- PDF: require TAP status EXPORTED unless adminOverride; logs EXPORT_PDF or EXPORT_PDF_ADMIN_OVERRIDE with current user when tapCode provided.
- Both flows fail fast on missing manifest/audit/pages to avoid incomplete exports.

## Done / Not done
- Done: manifest/audit/README validation before ZIP; README enriched from tap_manifest; adminOverride plumbed through ZipService UI; PDF generation validated against manifest ordering and audited.
- Not done: no changes to native scan/zip engines, file naming, folder structure, or audit JSON schema; no Phase 5 scope started.

## Status
Ready for Phase 5.
