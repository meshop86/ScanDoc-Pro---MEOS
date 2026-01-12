# Phase 12 – PRO Tier Activation & Encrypted Drive Backup

## Architecture
- **PRO Entitlement (local-only)**: `pro_entitlement_service.dart` stores `active` flag in app documents (`pro_entitlement.json`). No server dependency; app runs fully without login.
- **Google Drive Access**: `google_drive_service.dart` uses Google Sign-In with scope `https://www.googleapis.com/auth/drive.appdata`. Auth headers feed Drive API client for AppData uploads only.
- **Encrypted Backup Pipeline**: `backup_service.dart`
  1) Zip local data folder (`HoSoXe`) via `archive` (no changes to existing scan/zip/pdf/audit engines).
  2) Encrypt ZIP with AES-256-GCM. Key stored locally (`backup_key.bin`, 32 bytes). Output format: `nonce | ciphertext | mac`.
  3) Upload encrypted bytes to Drive AppData (filename `scandoc_backup_<timestamp>.enc`).
- **Settings UI**: `pro_settings_page.dart`
  - PRO status toggle (local entitlement)
  - Google connect/disconnect
  - Backup now (encrypt + upload)
  - Restore button shown but disabled (per requirement)
- **Entry Point**: Added "PRO & Backup" button in TapManagePage AppBar to open settings.

## Security
- AES-256-GCM encryption before upload; nonce 12 bytes; MAC from algorithm appended.
- Key generation: random 32-byte key stored locally (`backup_key.bin`). No key escrow/off-device storage.
- Drive scope restricted to `drive.appdata` only; no file or profile scopes.
- No analytics, no tracking, no new network calls beyond Drive upload.
- App remains fully usable offline; backup optional and PRO-gated.

## App Store Compliance
- Offline-first preserved; cloud optional and gated.
- Permissions: Google Sign-In (AppData only), camera/file storage unchanged.
- No in-app purchases implemented (local PRO flag). If later monetized, align with Store policies.
- User data: encrypted prior to upload; stored in AppData (not user-visible). Privacy policy must mention optional encrypted backup and local key storage.

## Known Limitations / Follow-ups
- Key is stored locally; device loss = inability to decrypt backups. Consider secure enclave/keychain storage and key export/import flow in future.
- Restore flow UI disabled; implementation pending (requires download + decrypt + merge with local data).
- Backup file size equals full `HoSoXe` tree; no incremental backups.
- Error handling minimal; add retries and upload progress in next phase.
- No rotation/cleanup of old backups in AppData; consider retention policy.

## Testing Notes (target)
- Verify PRO toggle persists across app restarts.
- Backup flow: PRO active + Google connected → "Backup now" uploads encrypted file; confirm file in Drive AppData via API tools.
- Offline mode: app runs without Google sign-in and without PRO enabled.
- iOS device: ensure Google Sign-In succeeds and backup completes; confirm no impact to scanning/zip/pdf/audit flows.
