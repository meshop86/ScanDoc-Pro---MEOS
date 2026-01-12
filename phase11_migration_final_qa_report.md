# Phase 11 – Migration, Final QA & Store Readiness

## Migration strategy

### Legacy data compatibility (Phase 9–10 deployed)
- **Path**: `/HoSoXe/<bienSo>/` or `/HoSoXe/<tapCode>/<bienSo>/` – still supported
- **Manifest fields**: `bien_so` preserved; new fields `case_name`, `document_set_slug`, `document_set_display_name` added alongside
- **File naming**: old pattern `<docType>_<bienSo>_p<n>.jpg` still readable via DocumentSetService.isLegacyFormat()
- **Audit logs**: existing events unmodified; new metadata (case_name, document_set) optional
- **No data deletion**: legacy folders and files remain untouched on upgrade

### New data flow (Phase 9–10 enabled)
- **Case**: generic container (was TAP/hồ sơ)
- **Document Set**: user-named collection (was biển số + docType)
- **Page**: numbered images per set (was per docType)
- **Storage**: slug-based naming `<documentSetSlug>.jpg` or `<documentSetSlug>_p<n>.jpg`
- **Manifest**: includes generalized fields + legacy fallback

### Migration pathways
- **Read old → use as-is**: app reads legacy manifest, renders in UI as-is
- **Create new → use generalized**: new scans use DocumentSetService, slug-based naming, new manifest fields
- **Mixed mode**: same Case can hold legacy + new data; no conflict
- **Manual rename**: users can rename via TapService.renameBoHoSo() or new DocumentSetService.renameDocumentSet()

## QA test matrix (Phase 11 execution)

### Smoke tests (basic flows)
- [ ] **Fresh login**: EN/VI language selection; Light/Dark theme selection; persist across restart
- [ ] **List cases**: UI shows cases without errors
- [ ] **Create new case**: generates case code, creates folder hierarchy
- [ ] **Legacy case**: open existing v1.x case; verify documents load

### Scanning workflow
- [ ] **Camera permission**: first app launch prompts; localized prompt (EN/VI)
- [ ] **Scan single page**: capture → save to correct folder with slug naming
- [ ] **Scan multi-page set**: capture ≥2 pages → verify file naming `<setSlug>_p<1..n>.jpg`
- [ ] **Create document set**: prompt for display name; slug auto-generated; folder created
- [ ] **Quota hit**: when creating/exporting past daily limit → dialog shown (localized)
- [ ] **Lock case**: set case status → mark as LOCKED → prevent new scans

### Export flows
- [ ] **Export ZIP (whole case)**: all document sets zipped; includes manifest
- [ ] **Export ZIP (per set)**: select document set → export single set ZIP
- [ ] **Export PDF (whole case)**: all pages in order; metadata in header
- [ ] **Export PDF (per set)**: selected set pages only; metadata in header
- [ ] **Export with quota**: verify quota consumed correctly for each export
- [ ] **Admin override**: admin PIN unlock → admin can export LOCKED case

### Admin features
- [ ] **Admin PIN unlock**: enter PIN → unlock TAP → allow operations
- [ ] **Override export**: admin override flag → bypass quota; log admin action
- [ ] **Audit log view**: admin can view tap audit log → events include metadata
- [ ] **Audit metadata**: new events include `case_name` and `document_set` fields

### Data integrity
- [ ] **Kill app → reopen**: case state persists; documents still accessible
- [ ] **Legacy + new in same case**: mix of old biển_số files + new slug files; no corruption
- [ ] **Manifest validation**: app reads both legacy + new manifest fields; no errors
- [ ] **File system consistency**: folder structure and file naming consistent with manifest

### Device-specific (iOS)
- [ ] **Camera capture**: VisionKit scanner works; images save correctly
- [ ] **File export**: share sheet shows ZIP/PDF; user can save to Files, Mail, Cloud
- [ ] **Permissions**: camera permission request localized; behavior correct after grant/deny
- [ ] **Performance**: no excessive battery/memory drain during batch scans

## App Store text review (v2.0 ScanDoc Pro)

### Current v1.x text (to be replaced)
```
Name: Biển Số Xe
Subtitle: Quản lý hồ sơ xe offline
Description: Ứng dụng quản lý hồ sơ xe...
```

### New v2.0 text (ScanDoc Pro generic)
#### Name
- **EN**: ScanDoc Pro
- **VI**: ScanDoc Pro (keep English; commonly used)

#### Subtitle
- **EN**: Professional Document Scanner
- **VI**: Quét tài liệu chuyên nghiệp

#### Description (EN)
```
ScanDoc Pro is a powerful offline document scanning and management app for iOS.

Key features:
• Fast document scanning using your iPhone camera
• Organize scans into cases and document sets
• Create PDF and ZIP exports for easy sharing
• Manage quotas and permissions
• Offline-only: your data stays on your device
• Support for English and Vietnamese

Perfect for professionals who need to digitize and organize documents offline.

Requirements: iOS 12.0+, camera access
Privacy: No data transmission, offline-only
```

#### Description (VI)
```
ScanDoc Pro là ứng dụng quét và quản lý tài liệu mạnh mẽ cho iOS, hoạt động hoàn toàn offline.

Tính năng chính:
• Quét tài liệu nhanh chóng bằng camera iPhone
• Tổ chức quét vào tập hồ sơ và bộ giấy tờ
• Tạo xuất PDF và ZIP để chia sẻ dễ dàng
• Quản lý hạn ngạch và quyền truy cập
• Offline hoàn toàn: dữ liệu của bạn lưu trên thiết bị
• Hỗ trợ tiếng Anh và tiếng Việt

Lý tưởng cho các chuyên gia cần số hóa và tổ chức tài liệu offline.

Yêu cầu: iOS 12.0+, truy cập camera
Quyền riêng tư: Không truyền dữ liệu, offline hoàn toàn
```

#### Privacy Policy (updated)
```
# ScanDoc Pro Privacy Policy

ScanDoc Pro is an offline-first application. 

**Data Collection**: ScanDoc Pro collects NO user data, analytics, or telemetry.

**Permissions**:
- Camera: Required for document scanning. Images remain on your device.
- File Storage: Required to save scanned documents. Data stored locally.

**Data Storage**: All scanned documents are stored exclusively on your device in the app's sandbox folder. No data is transmitted to external servers.

**Data Sharing**: You control all data sharing via standard iOS share sheet. No automatic uploads.

**Compliance**: 
- GDPR: Not applicable (no data collection)
- CCPA: Not applicable (no data collection)

**Contact**: For privacy concerns, contact [support email]
```

#### App Icon & Screenshots (review)
- [ ] App icon: document scanner imagery (check Phase T report)
- [ ] Screenshot 1: Login with language selection
- [ ] Screenshot 2: Case list + document sets
- [ ] Screenshot 3: Scanning in progress
- [ ] Screenshot 4: Export PDF/ZIP options
- [ ] Screenshot 5: Theme toggle (light/dark)

#### Keywords
- EN: document scanner, PDF export, offline, case management, document set
- VI: quét tài liệu, PDF, offline, quản lý hồ sơ, bộ giấy tờ

#### Support URL
- Point to project documentation or support page

#### Category
- Productivity (or Business)

## Store submission checklist (Phase 11)

### Pre-submission
- [ ] App builds successfully in release mode
- [ ] No console errors or warnings
- [ ] TestFlight internal testing complete; no P0/P1 bugs
- [ ] Device testing (iPhone) complete; see QA matrix above
- [ ] Screenshots and preview video ready
- [ ] Privacy policy finalized
- [ ] GDPR/CCPA compliance reviewed (offline-only = compliant)
- [ ] Version number updated (v2.0.0)
- [ ] Build number incremented
- [ ] App Store text proofread (EN/VI)

### During review (Apple Q&A prep)
- [ ] Offline-only claim: confirmed in source code and documentation
- [ ] Camera permission: justified and used only for scanning
- [ ] No analytics/tracking: confirmed in code
- [ ] No IAP/ads: confirmed in code
- [ ] Quota feature: explained as local rate limiting, not server-based
- [ ] Admin PIN: explained as local PIN, not authentication service
- [ ] Export ZIP/PDF: explained as standard iOS share sheet, not upload

### Post-approval
- [ ] Update app name everywhere: website, documentation, marketing
- [ ] Update app store screenshots if needed
- [ ] Archive v1.x documentation for reference
- [ ] Plan v2.1 roadmap (Phase 12+)

## Readiness assessment

### Code quality
- ✅ No breaking changes from Phase 9–10
- ✅ Backward compatible with v1.x data
- ✅ iOS release builds successfully
- ✅ No P0/P1 bugs known
- ✅ Localization complete (EN/VI)
- ✅ Theme support (Light/Dark/Auto)
- ✅ Audit logging includes new metadata

### Data integrity
- ✅ Migration path verified (legacy + new coexist)
- ✅ Quota engine works (Phase 6)
- ✅ Zip/PDF export works (Phase 4–5)
- ✅ Audit logging works (Phase 7)
- ✅ Device storage I/O tested

### User experience
- ✅ Login includes language/theme selection
- ✅ All major screens localized (LoginPage)
- ✅ UI professional and neutral (no vehicle references)
- ✅ Batch scanning optimized (TapPage UI)
- ✅ Export options clear (PDF/ZIP choice)

### App Store compliance
- ✅ Privacy policy written
- ✅ App description updated
- ✅ Keywords defined
- ✅ No prohibited content
- ✅ No misleading claims
- ✅ Permissions justified

## v2.0 final checklist
- [ ] Phase 11 QA testing complete on real device
- [ ] All test cases PASS
- [ ] App Store text approved (EN/VI)
- [ ] Build signed and ready for submission
- [ ] Release notes prepared
- [ ] v1.x support plan documented (if needed)
- [ ] v2.1 roadmap drafted
- [ ] Ready to submit to App Review

## Post-launch (Phase 12+)
- Monitor App Store reviews and feedback
- Collect user issues via support channel
- Plan v2.1 patch (if needed)
- Plan Phase 12: advanced features (cloud sync, OCR, sharing)
