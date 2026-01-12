import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'tap_service.dart';
import 'manifest_service.dart';
import 'zip_service.dart';
import 'scan_page.dart';
import 'tap_status.dart';
import 'audit_service.dart';
import 'user_service.dart';
import 'label_model.dart';
import 'audit_events.dart';
import 'quota_service.dart';

/// TapPage - Quản lý TẬP HỒ SƠ (document sets)
class TapPage extends StatefulWidget {
  final String tapCode;
  final bool adminUnlocked;

  const TapPage({super.key, required this.tapCode, this.adminUnlocked = false});

  @override
  State<TapPage> createState() => _TapPageState();
}

class _TapPageState extends State<TapPage> {
  List<String> _boHoSoList = [];
  bool _isLoading = false;
  TapStatus _tapStatus = TapStatus.open;
  bool _adminUnlocked = false;
  Map<String, String> _tapUserLabels = {};
  bool get _isOpen => _tapStatus.isOpen;
  bool get _isLocked => _tapStatus.isLocked;
  bool get _isExported => _tapStatus.isExported;
  bool get _canEditLabels => _isOpen || _adminUnlocked;
  bool _showManualForm = false;
  bool _showLabelsPanel = false;

  final _plateNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBoHoSo();
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    super.dispose();
  }

  /// Load danh sách bộ hồ sơ trong TAP
  Future<void> _loadBoHoSo() async {
    setState(() => _isLoading = true);
    try {
      final list = await TapService.listBoHoSo(widget.tapCode);
      final status = await TapService.getTapStatus(widget.tapCode);
      final admin = widget.adminUnlocked || await UserService.isAdminUnlocked();
      final labels = await ManifestService.readTapUserLabels(widget.tapCode);
      setState(() {
        _boHoSoList = list;
        _tapStatus = status;
        _adminUnlocked = admin;
        _tapUserLabels = labels;
      });
    } catch (e) {
      _showError('Lỗi load danh sách: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Thêm bộ hồ sơ mới (tên tự do)
  Future<void> _addBoHoSo() async {
    if (_shouldBlockNotOpen()) return;
    final title = _plateNumberController.text.trim();

    if (title.isEmpty) {
      _showError('Please enter a title');
      return;
    }

    final bienSo = title;

    setState(() => _isLoading = true);
    try {
      await TapService.addBoHoSo(widget.tapCode, bienSo);
      _plateNumberController.clear();
      await _loadBoHoSo();
      _showSuccess('Đã thêm $bienSo');
    } catch (e) {
      _showError('Lỗi thêm bộ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Xoá bộ hồ sơ
  Future<void> _deleteBoHoSo(String bienSo) async {
    if (_shouldBlockNotOpen()) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xoá bộ hồ sơ $bienSo?'),
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
      await TapService.deleteBoHoSo(widget.tapCode, bienSo);
      final user = await _getUser();
      await AuditService.logAction(
        tapCode: widget.tapCode,
        userId: user.userId,
        userDisplayName: user.displayName,
        action: 'DELETE',
        eventType: AuditEventType.deleteBo,
        target: bienSo,
        caseState: _tapStatus.value,
      );
      await _loadBoHoSo();
      _showSuccess('Đã xoá $bienSo');
    } catch (e) {
      _showError('Lỗi xoá: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Đổi tên bộ hồ sơ (rename atomic)
  Future<void> _renameBoHoSo(String oldBienSo) async {
    if (_shouldBlockNotOpen()) return;
    final controller = TextEditingController(text: oldBienSo);
    final newBienSo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document Set'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newBienSo == null || newBienSo.isEmpty || newBienSo == oldBienSo) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await TapService.renameBoHoSo(widget.tapCode, oldBienSo, newBienSo);
      final user = await _getUser();
      await AuditService.logAction(
        tapCode: widget.tapCode,
        userId: user.userId,
        userDisplayName: user.displayName,
        action: 'RENAME',
        eventType: AuditEventType.renameBo,
        target: '$oldBienSo -> $newBienSo',
        caseState: _tapStatus.value,
      );
      await _loadBoHoSo();
      _showSuccess('Đã đổi tên: $oldBienSo → $newBienSo');
    } catch (e) {
      _showError('Lỗi đổi tên: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Check trạng thái bộ hồ sơ
  Future<bool> _checkBoComplete(String bienSo) async {
    return await TapService.isBoComplete(widget.tapCode, bienSo);
  }

  bool _shouldBlockNotOpen() {
    if (_tapStatus.isOpen) return false;
    final msg = _isLocked
      ? 'TAP đang LOCKED, chỉ admin mở khóa mới chỉnh sửa được'
      : 'TAP không ở trạng thái OPEN';
    _showError(msg);
    return true;
  }

  Future<UserInfo> _getUser() async {
    final current = await UserService.getCurrentUser();
    if (current == null) {
      return const UserInfo(userId: 'unknown_user', displayName: 'Unknown');
    }
    return UserInfo(
      userId: current['user_id'] ?? 'unknown_user',
      displayName: current['display_name'] ?? 'Unknown',
    );
  }

  Future<void> _updateTapLabel(String key, String value) async {
    final oldValue = _tapUserLabels[key];
    if (oldValue == value) return;
    if (!_canEditLabels) {
      _showError('Chỉ chỉnh label khi TAP ở trạng thái OPEN hoặc có quyền admin');
      return;
    }

    try {
      final user = await _getUser();
      final newLabels = Map<String, String>.from(_tapUserLabels)..[key] = value;
      await ManifestService.writeTapManifest(
        tapCode: widget.tapCode,
        userInfo: user,
        tapStatus: _tapStatus,
        userLabels: newLabels,
      );
      setState(() {
        _tapUserLabels = newLabels;
      });

      await AuditService.logAction(
        tapCode: widget.tapCode,
        userId: user.userId,
        userDisplayName: user.displayName,
        action: 'LABEL_SET',
        eventType: AuditEventType.labelSetTap,
        target: 'tap:$key:${oldValue ?? ''}->${value}',
        caseState: _tapStatus.value,
      );
      _showSuccess('Đã gán nhãn');
    } catch (e) {
      _showError('Lỗi lưu label: $e');
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
            labelText: 'Nhập mã PIN',
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

    if (!_isLocked) {
      _showError('Chỉ mở khóa khi TAP đang LOCKED');
      return;
    }

    final ok = await UserService.unlockWithPin(pin);
    if (!ok) {
      _showError('Sai PIN');
      return;
    }

    await TapService.setTapStatus(widget.tapCode, TapStatus.open);
    final user = await _getUser();
    await AuditService.logAction(
      tapCode: widget.tapCode,
      userId: user.userId,
      userDisplayName: user.displayName,
      action: 'ADMIN_UNLOCK',
      eventType: AuditEventType.adminUnlock,
      target: widget.tapCode,
      caseState: TapStatus.open.value,
    );

    setState(() {
      _tapStatus = TapStatus.open;
      _adminUnlocked = true;
    });
    _showSuccess('Đã mở khóa TAP');
  }

  /// Hoàn tất TAP: Sinh tap_manifest, ZIP, Share
  Future<void> _finalizeTap(BuildContext ctx) async {
    if (_boHoSoList.isEmpty) {
      _showError('TAP trống, chưa có bộ hồ sơ');
      return;
    }

    if (!_tapStatus.isOpen) {
      _showError('Chỉ TAP ở trạng thái OPEN mới được hoàn tất');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Load user info
      final user = await _getUser();

      final quota = await QuotaService.checkAndConsumeExport(
        userId: user.userId,
        userDisplayName: user.displayName,
        tapCode: widget.tapCode,
      );
      if (!quota.allowed) {
        _showPaywall(quota.message, quota.remaining, quota.limit);
        setState(() => _isLoading = false);
        return;
      }

      // 2. Lock trước khi ghi manifest
      await TapService.setTapStatus(widget.tapCode, TapStatus.locked);
      setState(() => _tapStatus = TapStatus.locked);

      // 3. Write manifest cho từng bộ hồ sơ
      for (final bienSo in _boHoSoList) {
        await ManifestService.writeManifest(
          bienSo: bienSo,
          userInfo: user,
          tapCode: widget.tapCode,
        );
      }

      // 4. Write tap_manifest.json
      await ManifestService.writeTapManifest(
        tapCode: widget.tapCode,
        userInfo: user,
        tapStatus: TapStatus.locked,
        userLabels: _tapUserLabels,
      );

      // 5. Đánh dấu EXPORTED trước khi share theo guard
      await TapService.setTapStatus(widget.tapCode, TapStatus.exported);
      setState(() => _tapStatus = TapStatus.exported);

      // Ghi lại manifest với trạng thái cuối EXPORTED
      await ManifestService.writeTapManifest(
        tapCode: widget.tapCode,
        userInfo: user,
        tapStatus: TapStatus.exported,
        userLabels: _tapUserLabels,
      );

      // 6. ZIP toàn bộ TAP - tên file = bộ hồ sơ đầu tiên
      final firstBienSo = _boHoSoList.first;
      final zipPath = await ZipService.zipTap(widget.tapCode, zipName: firstBienSo);

      // 7. Share
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        throw Exception('Không tìm thấy file ZIP');
      }

      // Get anchor for iOS share sheet
      final RenderBox? box = ctx.findRenderObject() as RenderBox?;
      final shareOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await Share.shareXFiles(
        [XFile(zipPath)],
        subject: 'Hồ sơ tập ${widget.tapCode}',
        sharePositionOrigin: shareOrigin,
      );

      await AuditService.logAction(
        tapCode: widget.tapCode,
        userId: user.userId,
        userDisplayName: user.displayName,
        action: 'ZIP_TAP',
        eventType: AuditEventType.finalizeTap,
        target: widget.tapCode,
        caseState: _tapStatus.value,
      );

      _showSuccess('✅ Đã ZIP & chia sẻ TAP (EXPORTED)');
    } catch (e) {
      _showError('Lỗi hoàn tất: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    _showBanner(msg, bg: Colors.red.shade50, fg: Colors.red.shade900);
  }

  void _showSuccess(String msg) {
    _showBanner(msg, bg: Colors.green.shade50, fg: Colors.green.shade900);
  }

  void _showBanner(String msg, {required Color bg, required Color fg}) {
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: bg,
        content: Text(msg, style: TextStyle(color: fg)),
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Build a CTA button for Quick Scan or Document Set
  Widget _buildCTAButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isEnabled ? Colors.blue[300]! : Colors.grey[300]!,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isEnabled ? Colors.blue[50] : Colors.grey[50],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isEnabled ? Colors.blue[700] : Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? Colors.blue[700] : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isEnabled ? Colors.grey[600] : Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show dialog to create a named document set
  void _showCreateDocumentSetDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Document Set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Set Name',
                  hintText: 'e.g., Client documents',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                _showError('Please enter a name');
                return;
              }
              Navigator.pop(ctx);
              // Trigger existing _addBoHoSo logic with name
              _plateNumberController.text = name;
              _addBoHoSo();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Build a single guideline item in the empty state
  Widget _buildGuidelineItem(String label, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.chevron_right, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPaywall(String message, int remaining, int limit) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: GestureDetector(
          onLongPress: _promptAdminUnlock,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  'Case: ${widget.tapCode}',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 8),
              Builder(builder: (context) {
                final bgColor = _isLocked
                    ? Colors.red.shade100
                    : _isExported
                        ? Colors.blue.shade100
                        : Colors.green.shade100;
                final fgColor = _isLocked
                    ? Colors.red
                    : _isExported
                        ? Colors.blue
                        : Colors.green;
                final icon = _isLocked
                    ? Icons.lock
                    : _isExported
                        ? Icons.check_circle
                        : Icons.lock_open;
                return Chip(
                  backgroundColor: bgColor,
                  avatar: Icon(icon, size: 16, color: fgColor),
                  label: Text(
                    _tapStatus.value,
                    style: TextStyle(color: fgColor, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // CTA: Quick Actions for first-time users
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                          'Choose how to start',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // CTA 1: Quick Scan
                          Expanded(
                            child: _buildCTAButton(
                              context: context,
                              icon: Icons.image,
                              title: 'Quick Scan',
                              description: 'Scan a single page',
                              onTap: _isOpen
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ScanPage(
                                            bienSo: 'quick_scan',
                                            tapCode: widget.tapCode,
                                            adminUnlocked: _adminUnlocked,
                                          ),
                                        ),
                                      ).then((_) => _loadBoHoSo());
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // CTA 2: Create Document Set
                          Expanded(
                            child: _buildCTAButton(
                              context: context,
                              icon: Icons.description,
                              title: 'Document Set',
                              description: 'Multi-page collection',
                              onTap: _isOpen ? () {
                                _showCreateDocumentSetDialog();
                              } : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('Advanced (manual entry)'),
                          onPressed: _isOpen
                              ? () => setState(() => _showManualForm = !_showManualForm)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),

                // Input: Add document set (traditional form)
                  if (_isOpen && _showManualForm)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                                'Manual entry (free text)',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _plateNumberController,
                                    decoration: const InputDecoration(
                                      labelText: 'Title',
                                      hintText: 'e.g., Registration bundle',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    textInputAction: TextInputAction.done,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add'),
                                  onPressed: (!_isOpen || _isLoading) ? null : _addBoHoSo,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                if (_isLocked)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This case is locked. Long-press title to unlock with PIN.',
                              style: TextStyle(color: Colors.red[700], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Label selection for TAP
                  if (_isOpen)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        margin: const EdgeInsets.only(top: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ExpansionTile(
                          initiallyExpanded: _showLabelsPanel,
                          onExpansionChanged: (open) => setState(() => _showLabelsPanel = open),
                          title: const Text('Tags (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Keep hidden until needed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: LabelPresets.tapUserLabels.map((opt) {
                                  final current = _tapUserLabels[opt.key];
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(opt.label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 180,
                                        child: DropdownButtonFormField<String>(
                                          value: current,
                                          decoration: const InputDecoration(border: OutlineInputBorder()),
                                          items: opt.values
                                              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                                              .toList(),
                                          onChanged: _canEditLabels ? (val) {
                                            if (val != null) _updateTapLabel(opt.key, val);
                                          } : null,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                // List document sets
                Expanded(
                  child: _boHoSoList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.document_scanner_outlined, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                    'No document sets yet',
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    border: Border.all(color: Colors.blue[200]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Getting started',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue[700]),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildGuidelineItem(
                                          'Quick Scan',
                                          'Use for a single page',
                                        Colors.blue[700]!,
                                      ),
                                      const SizedBox(height: 6),
                                      _buildGuidelineItem(
                                          'Document Set',
                                          'Use for multi-page documents',
                                        Colors.blue[700]!,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _boHoSoList.length,
                          itemBuilder: (ctx, idx) {
                            final bienSo = _boHoSoList[idx];
                            return FutureBuilder<bool>(
                              future: _checkBoComplete(bienSo),
                              builder: (ctx, snap) {
                                final isComplete = snap.data ?? false;
                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isComplete ? Colors.green[500] : Colors.orange[500],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${idx + 1}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      bienSo,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      isComplete ? '✓ Complete' : '⚠ Incomplete',
                                      style: TextStyle(
                                        color: isComplete ? Colors.green[700] : Colors.orange[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        Tooltip(
                                          message: 'Edit',
                                          child: IconButton(
                                            icon: const Icon(Icons.edit, size: 20),
                                            onPressed: !_isOpen
                                                ? null
                                                : () => _renameBoHoSo(bienSo),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Delete',
                                          child: IconButton(
                                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                            onPressed: !_isOpen
                                                ? null
                                                : () => _deleteBoHoSo(bienSo),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: !_isOpen
                                        ? () => _showError('Case is locked')
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ScanPage(
                                                  bienSo: bienSo,
                                                  tapCode: widget.tapCode,
                                                  adminUnlocked: _adminUnlocked,
                                                ),
                                              ),
                                            ).then((_) => _loadBoHoSo());
                                          },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                // Button: Finalize Case
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle, size: 22),
                      label: const Text(
                        'Finalize & Export',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      onPressed: _boHoSoList.isEmpty
                          ? null
                          : (!_isOpen ? null : () => _finalizeTap(context)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
