# Phase 2 Case Workflow Report

## Lifecycle sau Phase 2
- DRAFT → OPEN → LOCKED → EXPORTED (TapStatus)
- Thao tác chính:
  - Scan/Retake/Delete/Save page: chỉ khi OPEN
  - Lock: từ OPEN chuyển LOCKED (khi finalize)
  - Export (ZIP/Share): thực hiện khi state đã chuyển EXPORTED
  - Unlock: chỉ khi LOCKED và nhập Admin PIN

## Guard rails đã áp dụng
- Enforce OPEN cho mọi thao tác ghi/xóa file scan (save/delete page/document/hoso) qua ScanFileService và ScanPage.
- Tap operations (add/delete/rename bộ hồ sơ, vào ScanPage) chỉ khi OPEN; UI disable và thông báo nghiệp vụ rõ ràng.
- ScanPage trong TAP: chặn share/zip lẻ, chỉ lưu manifest và yêu cầu quay lại TAP; nút share disable khi không OPEN.
- Finalize TAP: yêu cầu state OPEN; set LOCKED trước khi ghi manifest, chuyển EXPORTED trước share, ghi lại tap_manifest với EXPORTED; audit chỉ log sau export thành công, không log attempt bị chặn.
- Admin unlock: chỉ cho phép khi TAP đang LOCKED.
- TapManagePage: ZIP/Share chỉ khi TAP đã EXPORTED; rename chỉ khi OPEN (hoặc admin); trạng thái hiển thị màu/icon theo state.
- Manifest & completeness giữ nguyên naming `<docType>_<bienSo>_p<n>.jpg` từ Phase 1.

## Sẵn sàng Phase 3
- Case lifecycle và guard rails đã được cưỡng chế ở cả service và UI, tránh luồng "scan tiêu dùng".
- Audit/manifest vẫn giữ format, chỉ ghi khi hành động hợp lệ.
- Engine scan/zip/audit/lock không thay đổi cấu trúc; sẵn sàng mở rộng kiểm thử hoặc bổ sung rule ở Phase 3.
