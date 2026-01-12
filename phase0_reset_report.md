# Phase 0 Reset Report

## Domain mapping
- Case (đơn vị cao nhất yêu cầu): Hiện tương đương **TAP** (folder `HoSoXe/TAP_xxx`) đóng vai trò bao lô nhiều bộ hồ sơ. Ngoài TAP còn có chế độ đơn lẻ (không tapCode) lưu trực tiếp `HoSoXe/<bien_so>`.
- Document (container logic): Mỗi **bộ hồ sơ theo biển số** (variable `bienSo` trong ScanPage/TapPage) chứa các tài liệu con (`docType`: `to_khai`, `nguon_goc`, custom). Thực tế, code gọi là "bộ hồ sơ" hoặc "biển số"; đây là level giữa Case và Page.
- Page: File ảnh đã scan, lưu theo pattern hiện tại `<docType>_<bienSo>_p<n>.jpg` trong thư mục bộ hồ sơ.
- Phụ trợ: `TapStatus` (OPEN/LOCKED) khóa toàn bộ Case (TAP) và chặn lưu/xóa; `audit_log.json` ghi theo TAP.

## Case lifecycle (TAP)
- Tạo TAP: [TapManagePage](lib/scan/tap_manage_page.dart) gọi `TapService.generateTapCode()` + `createTap()` tạo thư mục `HoSoXe/TAP_xxx` và trạng thái OPEN.
- Thêm bộ hồ sơ (per biển số): [TapPage](lib/scan/tap_page.dart) → `TapService.addBoHoSo(tapCode, bienSo)` tạo `HoSoXe/TAP_xxx/<bienSo>`; kiểm tra mở khóa trước khi thêm.
- Scan & lưu Page: [ScanPage](lib/scan/scan_page.dart) → `VisionScanService.scanDocument()` trả temp paths → `ScanFileService.saveScannedFiles()` copy vào thư mục bộ hồ sơ, đặt tên `<docType>_<bienSo>_p<n>.jpg`; bị chặn nếu TAP LOCKED.
- Manifest: `ManifestService.writeManifest()` và `writeTapManifest()` ghi metadata khi zip/share hoặc hoàn tất TAP. (Hiện regex manifest không khớp naming, xem bên dưới.)
- Zip & Share: Case đơn lẻ dùng `ZipService.zipHoso(bienSo)`; TAP dùng `ZipService.zipTap(tapCode, zipName: firstBienSo)` rồi share qua share_plus.
- Locking: `TapService.setTapStatus()` đặt OPEN/LOCKED; UI ngăn scan/save/delete khi LOCKED; admin unlock qua PIN offline.
- Audit: `AuditService.logAction()` ghi JSON per TAP (SCAN/DELETE/ZIP...)

## Naming & flow checks
- File naming hiện tại `<docType>_<bienSo>_p<n>.jpg`. Nhưng `ManifestService.writeManifest()` group bằng regex `^(.*?)_p(\d+)\.jpg$` và `TapService.isBoComplete()` tìm `to_khai_p*` (không có biển số). Kết quả: manifest không liệt kê trang, check hoàn tất luôn fail → cần đồng bộ naming.
- `ScanFileService.saveScannedFiles()` chứa đoạn thừa `await targetFile.delete();${bienSo}_` (không ảnh hưởng runtime do parser? có thể gây lỗi nếu phân tích) và log in ra tên cũ `${docType}_p${pageNumber}.jpg` không khớp pattern mới.
- `ScanPage` cho phép share ZIP riêng lẻ khi đang trong TAP mode nhưng không khóa/đổi trạng thái TAP (chỉ viết manifest). Dễ lệch quy trình hoàn tất TAP.
- `_savePage()` báo thành công dựa trên `_savedPages[_selectedDocType ?? '']` sau khi reset `_selectedDocType`, dẫn tới message luôn 0 trang.
- `TapPage._finalizeTap()` gọi `setTapStatus` + `logAction` hai lần liên tiếp (duplicate), có thể gây log noise.
- User info fallback cứng (`user_001`) và login chỉ là tên tự do; không gắn vào Case/TAP rõ ràng.

## Dấu hiệu "app scan tiêu dùng"
- DocumentType tùy ý thêm "Giấy tờ phát sinh", không ràng buộc schema Case → khó kiểm toán.
- Naming docType tự do + manifest regex không khớp cho thấy ưu tiên scan nhanh hơn tính toàn vẹn hồ sơ nghiệp vụ.
- Share ZIP ngay tại ScanPage (mode đơn lẻ) mà không enforce trạng thái Case/TAP, giống luồng chia sẻ ảnh tiêu dùng.
- Login/PIN offline tối giản, không ràng user vào Case lifecycle ngoại trừ audit khi có tapCode.

## Phase 1 – đề xuất chỉnh (không refactor lớn)
1) Đồng bộ naming: thống nhất pattern và cập nhật `ManifestService.writeManifest()` + `TapService.isBoComplete()` + logs để chấp nhận `<docType>_<bienSo>_p<n>.jpg` (hoặc đổi lại pattern cũ, nhưng phải nhất quán). 
2) Làm sạch `saveScannedFiles()` (bỏ chuỗi thừa, log đúng tên) để tránh lỗi tiềm ẩn và nhầm pattern.
3) Quy trình TAP: chặn share ZIP lẻ trong ScanPage khi có `tapCode`, hoặc ít nhất hiển thị cảnh báo rằng TAP chưa lock/zip. 
4) Sửa thông báo lưu trang trong `_savePage()` để hiển thị đúng số trang đã lưu. 
5) Tránh log/status đúp trong `_finalizeTap()`; ghi action một lần sau khi set status. 
6) Kiểm tra lại default user/id: khi audit hoặc manifest nên bắt buộc có user thực tế từ `UserService` thay vì fallback `user_001`.

## Ảnh hưởng kiến trúc
- Các đề xuất trên chỉ chạm vào naming + regex + kiểm tra flow; không đổi cấu trúc thư mục hay engine scan/zip/audit.
