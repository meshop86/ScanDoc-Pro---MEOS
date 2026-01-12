# Phase S – Submission & Soft Launch Plan

## Submission checklist
- Build: release mode, v1.0.0, debug/logging minimized; verify icons, splash, display name final.
- Permissions: camera (document scan); file/storage limited to app sandbox; no tracking/analytics; update usage descriptions accordingly.
- Data integrity: startup recovery enabled; quota/audit/manifest files validated.
- Export guards: TAP must be EXPORTED or admin override; quota blocks show user-friendly dialog.
- App Store metadata: name/subtitle/description/privacy/review notes prepared (see Phase R report).
- Test pass: smoke (create TAP, scan, export ZIP/PDF), admin unlock/override, quota block/paywall dialog.

## Submission strategy
- Path: Submit to App Review (public release) after a short TestFlight sanity (24–48h) with internal testers to confirm device coverage.
- Timing: avoid weekends/holidays; submit early in the week (Mon–Wed) morning PT to reduce queue time.
- Before Submit: run final release build on target devices (sim + one physical), clear app data, rerun smoke checklist.

## App Review Q&A (prep)
- What does the app do? → Offline document scanning/management for vehicle case files; organizes into TAP (cases), exports ZIP/PDF locally.
- Does it require login or server? → No. Offline-only; all data stored on-device.
- Why camera permission? → For scanning documents only; images stay local.
- Any tracking/analytics/ads? → None. No network calls for analytics or ads.
- How is admin PIN used? → Local-only PIN to unlock a locked TAP or allow admin override exports; no backend.
- How does quota work? → Local daily limits for creating TAPs/exports; on hit, app shows a local notice; no purchases/ads.
- Data transmission? → ZIP/PDF exports are local; sharing uses standard OS share sheet at user request; no automatic upload.

## Rejection playbook
- Missing info/metadata: update App Store metadata/permission strings and resubmit; keep answers concise.
- Performance/crash: reproduce on same OS/device, patch minimal fix (v1.0.x), rerun smoke, resubmit.
- Guideline 2.3/5.1 (permissions/privacy): clarify offline use in review notes and usage descriptions; ensure no unused permissions.
- Binary/metadata mismatch (version/build): align versionCode/versionName (Android) and CFBundleShortVersionString/Build (iOS), rebuild, resubmit.
- In-app purchase/ads concerns: reiterate no IAP/ads; ensure UI has no misleading purchase prompts.
- TUYỆT ĐỐI không: argue without evidence, submit untested binaries, add hidden behaviors, or ship new features to bypass review.

## Soft launch (0–30 days)
- Audience: small internal/partner group via TestFlight or limited App Store rollout (manual links).
- Feedback (no analytics): collect via direct user interviews, email support inbox, or shared doc/issue tracker; capture device/OS, steps, expected vs actual.
- Patch criteria for v1.0.1: any crash, data loss risk, export failure, permission blocks, or critical UX blocker. Non-critical copy/UI tweaks defer to v1.0.2+ or v2 roadmap.
- Monitoring: manual smoke weekly; check app store reviews and support inbox twice a week.

## Early ops rules
- Bugfix principles: minimal diffs, no scope creep, preserve offline model; update release notes and audit fixes.
- Review response: polite, factual, no marketing; offer workaround if available and invite direct contact.
- Roadmap v2.0: reopen only after the first 30-day window and stability sign-off (no P0/P1 bugs outstanding).
