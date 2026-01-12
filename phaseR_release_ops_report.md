# Phase R – Release & Ops Pack

## App Store submission content
- **Name:** ScanDoc Pro – MEOS
- **Subtitle:** Quản lý tập hồ sơ xe, hoạt động hoàn toàn offline.
- **Description:** ScanDoc Pro giúp thu thập, quản lý và xuất tập hồ sơ xe ngay trên thiết bị. Ứng dụng hoạt động offline-first, lưu dữ liệu cục bộ trong vùng an toàn của thiết bị, hỗ trợ quét tài liệu, tổ chức theo TAP/bộ hồ sơ, và xuất ZIP/PDF khi hoàn tất. Admin có thể mở khóa quy trình trong các trường hợp đặc biệt và theo dõi nhật ký thao tác nội bộ. Không cần tài khoản cloud, không đồng bộ mạng.
- **Privacy note:** Không thu thập hay theo dõi người dùng; không dùng analytics; dữ liệu (ảnh scan, manifest, audit) lưu cục bộ trong sandbox; chỉ dùng camera để quét tài liệu và quyền truy cập file giới hạn trong vùng ứng dụng.
- **App Review notes:**
  - Admin PIN dùng để mở khóa TAP ở trạng thái LOCKED hoặc thực hiện override xuất; PIN mặc định cấu hình trong app, không liên quan tới backend.
  - Quota miễn phí (local-only) giới hạn số lần tạo TAP và export mỗi ngày; khi hết quota, hiển thị thông báo nhẹ và cho phép liên hệ nâng cấp (không có IAP/ads).
  - Export ZIP/PDF chạy cục bộ; không truyền dữ liệu ra ngoài; audit log lưu offline.
  - Ứng dụng hoạt động hoàn toàn offline; không yêu cầu đăng nhập server hoặc internet.

## Release checklist (v1.0.0)
- Build: Release mode, debug prints minimized (no verbose flags in release target).
- Versioning: v1.0.0 (ensure pubspec version and iOS/Android project match before submit).
- Permissions: Camera (scan); file/storage limited to app sandbox; no location/microphone/network permissions required.
- Assets/config: Confirm app icon, launch screen, and display name final; ensure no test/demo data bundled.
- Export guards: TAP must be EXPORTED or admin override; quota blocks handled with user-friendly dialog.

## v1.x operations rules
- Allowed: Bugfixes, crash/stability patches, copy tweaks, permission string clarifications, quota/admin policy text updates.
- Forbidden: New features, new data schemas, cloud/IAP/ads integrations, workflow changes, or architectural shifts.
- Bugfix process: Reproduce → add minimal fix → run smoke (launch, create TAP, scan, export ZIP/PDF) → update audit/release notes → increment patch version (v1.0.x) → distribute.

## v2.0 roadmap (notes only)
- Optional cloud backup/sync with end-to-end encryption.
- Configurable quota tiers and optional IAP/enterprise licensing.
- Enhanced search/filter across TAPs and documents.
- OCR-based metadata extraction for faster labeling.
- Multi-device admin console for audit review and policy rollout.
