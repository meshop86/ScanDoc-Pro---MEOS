import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

/// LocalizationService – manages EN/VI language preference
/// Stores choice locally; provides translation helpers
class LocalizationService {
  static const String _prefFile = 'localization.json';
  static const String _defaultLanguage = 'vi';

  /// Get stored language preference or default to VI
  static Future<String> getLanguage() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/$_prefFile');
      if (!await file.exists()) return _defaultLanguage;
      
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data['language']?.toString() ?? _defaultLanguage;
    } catch (_) {
      return _defaultLanguage;
    }
  }

  /// Save language preference
  static Future<void> setLanguage(String language) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$_prefFile');
    await file.writeAsString(jsonEncode({'language': language}));
  }

  /// Check if language is Vietnamese
  static Future<bool> isVietnamese() async {
    final lang = await getLanguage();
    return lang == 'vi';
  }

  /// Translate key to VI or EN
  /// Returns English if language is 'en', Vietnamese otherwise
  static Future<String> translate(String key) async {
    final lang = await getLanguage();
    final translations = lang == 'en' ? _en : _vi;
    return translations[key] ?? key;
  }

  /// Batch translate (for efficiency)
  static Future<Map<String, String>> translateBatch(List<String> keys) async {
    final lang = await getLanguage();
    final translations = lang == 'en' ? _en : _vi;
    return {
      for (final key in keys)
        key: translations[key] ?? key
    };
  }

  // Vietnamese translations
  static const Map<String, String> _vi = {
    // Login & Auth
    'login_title': 'Đăng nhập',
    'login_user_id': 'Mã người dùng',
    'login_display_name': 'Tên hiển thị',
    'login_button': 'Đăng nhập',
    'language': 'Ngôn ngữ',
    'theme': 'Chủ đề',
    'light_mode': 'Sáng',
    'dark_mode': 'Tối',
    'system_default': 'Theo hệ thống',

    // Case/TAP management
    'cases': 'Tập hồ sơ',
    'case': 'Tập',
    'create_case': 'Tạo tập mới',
    'case_code': 'Mã tập',
    'case_name': 'Tên tập',
    'new_case': 'Tập mới',

    // Document Set
    'document_sets': 'Bộ giấy tờ',
    'document_set': 'Bộ giấy tờ',
    'add_document_set': 'Thêm bộ giấy tờ',
    'document_set_name': 'Tên bộ giấy tờ',
    'rename_document_set': 'Đổi tên bộ giấy tờ',
    'delete_document_set': 'Xoá bộ giấy tờ',

    // Scanning
    'scan': 'Quét',
    'scanning': 'Đang quét...',
    'scan_page': 'Quét trang',
    'add_page': 'Thêm trang',
    'page_count': 'Số trang',
    'pages': 'Trang',
    'page': 'Trang',

    // Export
    'export': 'Xuất',
    'export_zip': 'Xuất ZIP',
    'export_pdf': 'Xuất PDF',
    'export_options': 'Tùy chọn xuất',
    'whole_case': 'Toàn tập',
    'per_document_set': 'Theo bộ giấy tờ',

    // Actions
    'save': 'Lưu',
    'cancel': 'Huỷ',
    'delete': 'Xoá',
    'rename': 'Đổi tên',
    'lock': 'Khóa',
    'unlock': 'Mở khóa',
    'done': 'Xong',
    'confirm': 'Xác nhận',

    // Admin
    'admin': 'Quản trị',
    'admin_pin': 'Mã PIN quản trị',
    'admin_unlock': 'Mở khóa quản trị',
    'admin_override': 'Ghi đè quản trị',

    // Quota
    'quota_limit': 'Giới hạn hạn ngạch',
    'quota_remaining': 'Còn lại',
    'quota_exceeded': 'Đã vượt hạn ngạch',
    'daily_limit': 'Giới hạn hàng ngày',

    // Status
    'open': 'Mở',
    'locked': 'Khóa',
    'exported': 'Đã xuất',
    'completed': 'Hoàn thành',

    // Messages
    'success': 'Thành công',
    'error': 'Lỗi',
    'warning': 'Cảnh báo',
    'confirm_delete': 'Xác nhận xoá?',
    'confirm_action': 'Xác nhận thao tác?',
    'loading': 'Đang tải...',
    'no_data': 'Không có dữ liệu',

    // Settings
    'settings': 'Cài đặt',
    'user_info': 'Thông tin người dùng',
    'preferences': 'Tùy chọn',
    'about': 'Về ứng dụng',
    'version': 'Phiên bản',
    'logout': 'Đăng xuất',

    // Permissions
    'camera_permission': 'Cho phép truy cập camera để quét tài liệu',
    'permission_denied': 'Quyền bị từ chối',
    'permission_required': 'Cần thiết quyền để tiếp tục',
  };

  // English translations
  static const Map<String, String> _en = {
    // Login & Auth
    'login_title': 'Sign In',
    'login_user_id': 'User ID',
    'login_display_name': 'Display Name',
    'login_button': 'Sign In',
    'language': 'Language',
    'theme': 'Theme',
    'light_mode': 'Light',
    'dark_mode': 'Dark',
    'system_default': 'System',

    // Case/TAP management
    'cases': 'Cases',
    'case': 'Case',
    'create_case': 'Create New Case',
    'case_code': 'Case Code',
    'case_name': 'Case Name',
    'new_case': 'New Case',

    // Document Set
    'document_sets': 'Document Sets',
    'document_set': 'Document Set',
    'add_document_set': 'Add Document Set',
    'document_set_name': 'Document Set Name',
    'rename_document_set': 'Rename Document Set',
    'delete_document_set': 'Delete Document Set',

    // Scanning
    'scan': 'Scan',
    'scanning': 'Scanning...',
    'scan_page': 'Scan Page',
    'add_page': 'Add Page',
    'page_count': 'Page Count',
    'pages': 'Pages',
    'page': 'Page',

    // Export
    'export': 'Export',
    'export_zip': 'Export ZIP',
    'export_pdf': 'Export PDF',
    'export_options': 'Export Options',
    'whole_case': 'Whole Case',
    'per_document_set': 'Per Document Set',

    // Actions
    'save': 'Save',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'rename': 'Rename',
    'lock': 'Lock',
    'unlock': 'Unlock',
    'done': 'Done',
    'confirm': 'Confirm',

    // Admin
    'admin': 'Admin',
    'admin_pin': 'Admin PIN',
    'admin_unlock': 'Admin Unlock',
    'admin_override': 'Admin Override',

    // Quota
    'quota_limit': 'Quota Limit',
    'quota_remaining': 'Remaining',
    'quota_exceeded': 'Quota Exceeded',
    'daily_limit': 'Daily Limit',

    // Status
    'open': 'Open',
    'locked': 'Locked',
    'exported': 'Exported',
    'completed': 'Completed',

    // Messages
    'success': 'Success',
    'error': 'Error',
    'warning': 'Warning',
    'confirm_delete': 'Confirm delete?',
    'confirm_action': 'Confirm action?',
    'loading': 'Loading...',
    'no_data': 'No data',

    // Settings
    'settings': 'Settings',
    'user_info': 'User Info',
    'preferences': 'Preferences',
    'about': 'About',
    'version': 'Version',
    'logout': 'Sign Out',

    // Permissions
    'camera_permission': 'Allow camera access to scan documents',
    'permission_denied': 'Permission Denied',
    'permission_required': 'Permission required to continue',
  };
}
