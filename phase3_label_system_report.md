# Phase 3 Label System Report

## Schema label
- Scope: TAP (Case) và Document (biển số); không áp dụng Page.
- manifestVersion: "1.1" (giữ key cũ, chỉ bổ sung).
- Cấu trúc labels:
  - `labels.system`: auto, read-only (tap_code, state cho TAP; tap_code/bien_so cho Document).
  - `labels.user`: chọn từ danh sách cấu hình (không free-text).
- Preset user labels:
  - TAP: `priority` (low|normal|high), `channel` (onsite|drop_off|other).
  - Document: `quality` (ok|blur|shadow), `verification` (pending|verified|rejected).

## Manifest sample
```json
{
  "manifestVersion": "1.1",
  "tap_code": "TAP_001",
  "created_at": "2026-01-04T10:00:00Z",
  "created_by": {"user_id": "user_123", "display_name": "Alice"},
  "tap_status": "EXPORTED",
  "bo_ho_so": [{"bien_so": "14Bx-4524", "folder": "14Bx-4524"}],
  "labels": {
    "system": {"tap_code": "TAP_001", "state": "EXPORTED"},
    "user": {"priority": "high", "channel": "onsite"}
  }
}
```

```json
{
  "manifestVersion": "1.1",
  "bien_so": "14Bx-4524",
  "created_at": "2026-01-04T10:00:00Z",
  "created_by": {"user_id": "user_123", "display_name": "Alice"},
  "device": {"platform": "iOS", "model": "iPhone", "os_version": "..."},
  "documents": [
    {"type": "to_khai", "required": true, "pages": ["to_khai_14Bx-4524_p1.jpg"]}
  ],
  "labels": {
    "system": {"tap_code": "TAP_001", "bien_so": "14Bx-4524"},
    "user": {"quality": "ok", "verification": "verified"}
  }
}
```

## Guard rules
- Chỉnh label chỉ khi TAP ở trạng thái OPEN; admin PIN có thể override. Khi LOCKED/EXPORTED mà không có admin: label readonly, UI disable và hiển thị lý do.
- Scan/Delete vẫn tuân thủ guard OPEN từ Phase 2; không bị ảnh hưởng.
- Share/ZIP trong TAP vẫn chỉ khi EXPORTED; ScanPage trong TAP không share lẻ.
- Audit chỉ log khi giá trị label thay đổi; không log attempt bị chặn.

## Thay đổi chính
- Thêm preset label model (system/user, không free-text) [lib/scan/label_model.dart](lib/scan/label_model.dart).
- Mở rộng manifest với `manifestVersion` và `labels` (giữ key cũ) + load/merge label hiện hữu; hàm đọc label tiện ích [lib/scan/manifest_service.dart](lib/scan/manifest_service.dart).
- TAP-level label UI + guard + audit in [lib/scan/tap_page.dart](lib/scan/tap_page.dart); label được lưu vào tap_manifest và tôn trọng admin unlock.
- Document-level label UI + guard + audit in [lib/scan/scan_page.dart](lib/scan/scan_page.dart); lưu vào manifest từng biển số, disable nếu TAP không OPEN (trừ admin).
- TapManagePage tôn trọng state khi ZIP/Share (EXPORTED) và phản ánh màu/icon theo state [lib/scan/tap_manage_page.dart](lib/scan/tap_manage_page.dart).

## Sẵn sàng Phase 4
- Label/metadata được kiểm soát (không free-text), gắn vào manifest 1.1, có guard theo state và audit rõ ràng.
- Không thay đổi engine scan/zip/audit/lock; cấu trúc thư mục giữ nguyên.
- UI đã hiển thị và chỉnh label ở TAP overview và Document view với disable/hint phù hợp.
