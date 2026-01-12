import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'tap_service.dart';
import 'tap_page.dart';
import 'tap_status.dart';
import 'user_service.dart';
import 'zip_service.dart';
import 'manifest_service.dart';
import 'login_page.dart';
import 'admin_audit_viewer.dart';
import 'admin_tools_page.dart';
import 'quota_service.dart';
import 'audit_events.dart';
import 'pro_settings_page.dart';

/// TapManagePage - Trang quản lý TẬP HỒ SƠ (root page)
class TapManagePage extends StatefulWidget {
  const TapManagePage({super.key});

  @override
  State<TapManagePage> createState() => _TapManagePageState();
}

class _TapManagePageState extends State<TapManagePage> {
  List<String> _taps = [];
  bool _isLoading = false;
  bool _adminUnlocked = false;
  final Map<String, String> _tapNames = {};

  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTaps();
  }

  Future<void> _loadTaps() async {
    setState(() => _isLoading = true);
    try {
      final taps = await TapService.listTaps();
      final admin = await UserService.isAdminUnlocked();
      final Map<String, String> names = {};
      for (final tap in taps) {
        final name = await _readTapName(tap);
        if (name != null && name.isNotEmpty) {
          names[tap] = name;
        }
      }
      setState(() {
        _taps = taps;
        _adminUnlocked = admin;
        _tapNames
          ..clear()
          ..addAll(names);
      });
    } catch (e) {
      _showError('Lỗi load danh sách: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewTap() async {
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Case'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Case Name',
                hintText: 'e.g., Vehicle Documentation',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameController.text.trim();

    final user = await UserService.getCurrentUser();
    final quota = await QuotaService.checkAndConsumeTap(
      userId: user?['user_id'] ?? 'unknown',
      userDisplayName: user?['display_name'],
    );
    if (!quota.allowed) {
      _showPaywall(quota.message, remaining: quota.remaining, limit: quota.limit);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final tapCode = await TapService.generateTapCode();
      await TapService.createTap(tapCode);
      if (name.isNotEmpty) {
        await _writeTapName(tapCode, name);
      }
      await _loadTaps();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TapPage(tapCode: tapCode, adminUnlocked: _adminUnlocked),
          ),
        ).then((_) => _loadTaps());
      }
    } catch (e) {
      _showError('Lỗi tạo Case: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTap(String tapCode) async {
    if (!_adminUnlocked) {
      _showError('Chỉ admin mới được xoá TAP');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xoá toàn bộ Tập $tapCode?\nKhông thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await TapService.deleteTap(tapCode);
      await _loadTaps();
      _showSuccess('Đã xoá $tapCode');
    } catch (e) {
      _showError('Lỗi xoá: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _promptAdminUnlock() async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin unlock'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Mã PIN',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Mở')),
        ],
      ),
    );

    if (pin == null || pin.isEmpty) return;

    final ok = await UserService.unlockWithPin(pin);
    if (!ok) {
      _showError('Sai PIN');
      return;
    }

    setState(() => _adminUnlocked = true);
    _showSuccess('Đã mở quyền admin');
  }

  Future<void> _showAuditLog(String tapCode) async {
    if (!_adminUnlocked) {
      _showError('Cần admin để xem audit log');
      return;
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/HoSoXe/$tapCode/audit_log.json');
      if (!await file.exists()) {
        _showError('Chưa có audit_log cho $tapCode');
        return;
      }
      final content = await file.readAsString();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Audit log - $tapCode'),
          content: SingleChildScrollView(
            child: SelectableText(content, style: const TextStyle(fontSize: 12)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        ),
      );
    } catch (e) {
      _showError('Lỗi đọc log: $e');
    }
  }

  Future<String?> _readTapName(String tapCode) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/HoSoXe/$tapCode/tap_manifest.json');
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      if (data is Map && data['tap_name'] != null) {
        return data['tap_name'].toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeTapName(String tapCode, String tapName) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/HoSoXe/$tapCode/tap_manifest.json');
    Map<String, dynamic> payload = {
      'tap_code': tapCode,
      'tap_name': tapName,
    };
    try {
      if (await file.exists()) {
        final existing = jsonDecode(await file.readAsString());
        if (existing is Map<String, dynamic>) {
          existing['tap_name'] = tapName;
          payload = existing;
        }
      } else {
        final status = await TapService.getTapStatus(tapCode);
        payload['tap_status'] = status.value;
        payload['bo_ho_so'] = await TapService.listBoHoSo(tapCode);
      }
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    } catch (e) {
      _showError('Lỗi lưu tap_name: $e');
    }
  }

  Future<void> _renameTap(String tapCode) async {
    final currentName = _tapNames[tapCode] ?? tapCode;
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa tên Tập'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tên Tập mới',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    setState(() => _isLoading = true);
    try {
      await _writeTapName(tapCode, newName);
      _tapNames[tapCode] = newName;
      setState(() {});
      _showSuccess('Đã đổi tên hiển thị');
    } catch (e) {
      _showError('Lỗi đổi tên: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _zipAndShareTap(String tapCode, BuildContext ctx) async {
    final status = await TapService.getTapStatus(tapCode);
    final adminOverride = _adminUnlocked && !status.isExported;
    if (!status.isExported && !adminOverride) {
      _showError('Chỉ TAP ở trạng thái EXPORTED mới được ZIP/Share. Vào TAP để hoàn tất hoặc dùng admin override.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await UserService.getCurrentUser();
      final userInfo = UserInfo(
        userId: user?['user_id'] ?? 'unknown',
        displayName: user?['display_name'] ?? 'Unknown',
      );

      final quota = await QuotaService.checkAndConsumeExport(
        userId: userInfo.userId,
        userDisplayName: userInfo.displayName,
        tapCode: tapCode,
      );
      if (!quota.allowed) {
        _showPaywall(quota.message, remaining: quota.remaining, limit: quota.limit);
        setState(() => _isLoading = false);
        return;
      }

      final boList = await TapService.listBoHoSo(tapCode);
      if (boList.isEmpty) {
        _showError('TAP trống');
        setState(() => _isLoading = false);
        return;
      }

      // Write manifests
      for (final bo in boList) {
        await ManifestService.writeManifest(
          bienSo: bo,
          userInfo: userInfo,
          tapCode: tapCode,
        );
      }
      await ManifestService.writeTapManifest(
        tapCode: tapCode,
        userInfo: userInfo,
        tapStatus: status,
      );

      final zipPath = await ZipService.zipTap(
        tapCode,
        zipName: boList.first,
        adminOverride: adminOverride,
      );
      if (!await File(zipPath).exists()) {
        throw Exception('ZIP file not found');
      }

      final RenderBox? box = ctx.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await Share.shareXFiles(
        [XFile(zipPath)],
        subject: 'Hồ sơ $tapCode',
        sharePositionOrigin: origin,
      );

      final suffix = adminOverride ? ' (ADMIN OVERRIDE)' : '';
      _showSuccess('✅ Đã ZIP & chia sẻ $tapCode$suffix');
    } catch (e) {
      _showError('Lỗi ZIP: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (confirm != true) return;

    await UserService.logoutOffline();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _showError(String msg) {
    _showBanner(msg, color: Colors.red.shade50, textColor: Colors.red.shade900);
  }

  void _showPaywall(String message, {required int remaining, required int limit}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quota hạn chế'),
        content: Text('$message\nHôm nay: $remaining/$limit lượt còn lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Liên hệ nâng cấp'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    _showBanner(msg, color: Colors.green.shade50, textColor: Colors.green.shade900);
  }

  void _showBanner(String msg, {Color? color, Color? textColor}) {
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(msg, style: TextStyle(color: textColor ?? Colors.black87)),
        backgroundColor: color ?? Colors.blueGrey.shade50,
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTaps = _taps;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: GestureDetector(
          onLongPress: _promptAdminUnlock,
          child: const Text('ScanDoc Pro'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.backup_outlined, size: 24),
            tooltip: 'Backup & PRO',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProSettingsPage()),
              );
            },
          ),
          if (_adminUnlocked)
            IconButton(
              icon: const Icon(Icons.security_outlined, size: 24),
              tooltip: 'Admin',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminToolsPage()),
                );
              },
            ),
          if (_adminUnlocked)
            IconButton(
              icon: const Icon(Icons.history, size: 24),
              tooltip: 'Audit',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminAuditViewerPage()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 24),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _filter == 'all',
                          onSelected: (_) => setState(() => _filter = 'all'),
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue.shade50,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        FilterChip(
                          label: const Text('Open'),
                          selected: _filter == 'open',
                          onSelected: (_) => setState(() => _filter = 'open'),
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue.shade50,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        FilterChip(
                          label: const Text('Locked'),
                          selected: _filter == 'locked',
                          onSelected: (_) => setState(() => _filter = 'locked'),
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue.shade50,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        FilterChip(
                          label: const Text('Exported'),
                          selected: _filter == 'exported',
                          onSelected: (_) => setState(() => _filter = 'exported'),
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue.shade50,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadTaps,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Cases',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                icon: const Icon(Icons.add, size: 20),
                                onPressed: _createNewTap,
                                label: const Text('New Case'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (visibleTaps.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No cases yet',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create a case to start scanning.',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ...visibleTaps.map((tapCode) {
                          final displayName = _tapNames[tapCode] ?? tapCode;
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              title: Text(
                                displayName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'ID: $tapCode',
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: SizedBox(
                                width: 180,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'Rename',
                                      child: IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _renameTap(tapCode),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Backup & Share',
                                      child: IconButton(
                                        icon: const Icon(Icons.backup, size: 20, color: Colors.orange),
                                        onPressed: () => _zipAndShareTap(tapCode, context),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                      ),
                                    ),
                                    if (_adminUnlocked)
                                      Tooltip(
                                        message: 'Audit Log',
                                        child: IconButton(
                                          icon: const Icon(Icons.history, size: 20, color: Colors.blue),
                                          onPressed: () => _showAuditLog(tapCode),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                        ),
                                      ),
                                    if (_adminUnlocked)
                                      Tooltip(
                                        message: 'Delete',
                                        child: IconButton(
                                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                          onPressed: () => _deleteTap(tapCode),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TapPage(
                                      tapCode: tapCode,
                                      adminUnlocked: _adminUnlocked,
                                    ),
                                  ),
                                ).then((_) => _loadTaps());
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: null,
    );
  }
}
