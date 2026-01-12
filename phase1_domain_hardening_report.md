# Phase 1 Domain Hardening Report

## Các thay đổi đã thực hiện
- Đồng bộ manifest & kiểm tra hoàn tất với naming `<docType>_<bienSo>_p<n>.jpg`: cập nhật regex nhóm trang và kiểm tra đủ tờ khai trong [lib/scan/manifest_service.dart](lib/scan/manifest_service.dart) và [lib/scan/tap_service.dart](lib/scan/tap_service.dart).
- Làm sạch lưu file scan: bỏ chuỗi thừa, log đúng tên file trong [lib/scan/scan_file_service.dart](lib/scan/scan_file_service.dart).
- Siết share trong TAP: ở TAP mode chỉ lưu manifest và cảnh báo không share lẻ, dùng user thực để ghi manifest trong [lib/scan/scan_page.dart](lib/scan/scan_page.dart).
- Sửa UI/logic nhỏ: báo đúng số trang đã lưu, log action khớp filename, bỏ log/setStatus trùng khi hoàn tất TAP trong [lib/scan/scan_page.dart](lib/scan/scan_page.dart) và [lib/scan/tap_page.dart](lib/scan/tap_page.dart).
- Ràng buộc user thật cho audit/manifest (fallback chỉ Unknown khi không đăng nhập) trong [lib/scan/scan_page.dart](lib/scan/scan_page.dart) và [lib/scan/tap_page.dart](lib/scan/tap_page.dart).

## Domain mapping sau Phase 1
- Case: **TAP** (`HoSoXe/TAP_xxx`) – bao nhiều bộ hồ sơ, trạng thái OPEN/LOCKED, audit theo TAP.
- Document: **Bộ hồ sơ theo biển số** (`HoSoXe/TAP_xxx/<bienSo>` hoặc đơn lẻ `HoSoXe/<bienSo>`). Chứa nhiều docType (`to_khai`, `nguon_goc`, custom nếu cho phép).
- Page: File ảnh scan tên `<docType>_<bienSo>_p<n>.jpg`, được manifest liệt kê và được dùng để check đủ giấy tờ bắt buộc.

## Sẵn sàng cho Phase 2
- Naming/manifest/completeness đã thống nhất, tránh lệch giữa lưu file và kiểm tra.
- TAP flow đã ngăn share lẻ khi chưa hoàn tất; audit/manifest gắn với user đăng nhập.
- Kiến trúc và engine scan/zip/audit/lock giữ nguyên; các thay đổi nhỏ, tập trung vào contract. Sẵn sàng bước tiếp cho Phase 2.
