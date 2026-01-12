# Phase 6 – Commercial/Quota Layer

## Quota rules
- Local-only counters (reset daily) stored in quota_state.json.
- Limits: TAP creation ≤ 5/day, Export (ZIP/PDF) ≤ 10/day.
- Existing TAPs and in-case scanning are unaffected; quota only gates new TAP creation and new exports.

## Guard flow
- Actions check+consume quota before proceeding:
  - TAP create (TapManagePage)
  - Export ZIP in TAP finalize/share flows
  - Export ZIP/PDF via service (PDF guarded when not adminOverride)
- On block: QUOTA_BLOCKED audit + light paywall dialog; action is cancelled.
- On allowed: QUOTA_CHECK audit + quota decremented.

## Paywall UX
- Modal dialog (no ads/IAP): explains quota hit, shows remaining/limit, offers close or "Liên hệ nâng cấp" CTA (no network dependency).
- Does not interrupt in-case scanning/editing.

## Audit events
- Added: QUOTA_CHECK, QUOTA_BLOCKED, QUOTA_RESET.
- Each record includes user id/display, tap_code (GLOBAL when non-specific), case_state when applicable, timestamp, and meta with usage/limits.
- Admin quota reset is audited.

## Admin tools
- Admin Tools page can reset quota counters; existing admin unlock/re-export remain.

## Ready for Phase 7
Quota/paywall layer is in place, offline-safe, audited, and non-intrusive to existing cases. Prepared to plan Phase 7 when opened.
