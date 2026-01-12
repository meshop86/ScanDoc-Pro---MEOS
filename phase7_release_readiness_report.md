# Phase 7 – Release Readiness

## Hardening checklist
- Startup integrity guard: validates and recreates quota_state, tap_manifest, document manifests, and audit_log per TAP with SYSTEM_RECOVER audit tagging.
- Quota file normalized daily; recoveries proceed even if prior files missing/corrupt.
- Export/PDF ZIP guards unchanged (fail-fast with friendly messages surfaced by UI flows).

## Data integrity rules
- Missing/empty audit_log.json or manifest.json files are recreated with minimal valid content; recovery is audited.
- Quota state is persisted/normalized on launch; recovery audited when recreated.
- No schema changes; existing data layout preserved.

## App Store notes
- Description focus: offline-first TAP/document management, device-only storage, ZIP/PDF export, admin tools for audit/quota.
- Privacy: no tracking, no analytics, no cloud/backend; data stays on device; camera access solely for document scan; file access limited to app sandbox.

## Architecture freeze (v1.x)
- No network/cloud integrations, no IAP/ads, no analytics, no schema changes, no workflow changes beyond guards/recovery; current offline architecture is frozen for v1.x.

## Ready to release
All stability, integrity, and UX polish items for v1.x are in place; app is ready for submission.
