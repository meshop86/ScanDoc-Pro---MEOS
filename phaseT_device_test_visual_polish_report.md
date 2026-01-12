# Phase T – Device Test & Visual Polish Report

## Scope
- Target: iOS physical device (fresh install), v1.x frozen, no new features.
- Blocking fix policy: only crash, permission, IO/storage, or blocking UX; no refactors.

## Test matrix (planned)
- First launch & camera permission flow
- TAP lifecycle: Create TAP → Scan → Lock → Export ZIP/PDF
- Quota hit → paywall dialog renders and blocks action
- Admin PIN: unlock locked TAP → re-export
- Kill app → reopen → verify TAP data integrity

## Physical Device Execution
- Device: _pending real device run_ (record model + storage + region when executed).
- iOS: _pending_ (record exact iOS version).
- Install: fresh install required (delete prior app), from TestFlight/ad-hoc or USB.
- Result: **NOT RUN** → gate remains open until executed.

## Phase T2 outcome
- PASS/FAIL: **Pending** (set to PASS only after full device matrix succeeds without blocking issues).

## Execution status
- Test run: **Not executed yet** (must run on physical iPhone before submit).
- Simulator runs: previously green (prior phases), but simulator ≠ device parity for camera/permission/IO.

## Issues observed
- Not run on device → no findings yet.

## Visual polish checklist
- App Icon: verify simple, professional, high-contrast; ensure correct iOS asset variants (no missing sizes). Pending on-device confirmation.
- Launch Screen: ensure no debug text, no spinners/delays; confirm matches brand colors; pending on-device confirmation.

## Next actions to close Phase T
1) Install fresh build on physical iPhone (TestFlight ad-hoc or USB install). 
2) Run the full matrix above; record any device-only issues (camera permission, file export, share sheet, quota dialogs, admin PIN flow, relaunch integrity).
3) If bugs found: patch only blocking categories; rerun smoke; update this report (Issues + Status) and mark Ready.

## Ready-to-Submit gate
- Current status: **NOT READY** (physical device run not executed). 
- Action to flip to Ready: complete the physical device matrix with zero blocking issues, then set status to **READY TO SUBMIT** and log device/iOS info above.
