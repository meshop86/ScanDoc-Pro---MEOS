import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'audit_events.dart';
import 'audit_service.dart';
import 'pdf_service.dart';
import 'tap_service.dart';
import 'tap_status.dart';
import 'user_service.dart';
import 'zip_service.dart';
import 'quota_service.dart';

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({super.key});

  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage> {
  List<String> _taps = [];
  String? _selectedTap;
  List<String> _boList = [];
  String? _selectedBienSo;
  bool _loading = true;
  bool _busy = false;
  bool _adminUnlocked = false;
  TapStatus _tapStatus = TapStatus.open;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final admin = await UserService.isAdminUnlocked();
    final taps = await TapService.listTaps();
    setState(() {
      _adminUnlocked = admin;
      _taps = taps;
      _loading = false;
    });
  }

  Future<void> _loadTapContext(String tapCode) async {
    setState(() => _busy = true);
    try {
      final status = await TapService.getTapStatus(tapCode);
      final docs = await getApplicationDocumentsDirectory();
      final tapFolder = Directory('${docs.path}/HoSoXe/$tapCode');
      final boList = tapFolder
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split('/').last)
          .where((name) => !name.startsWith('.'))
          .toList();
      setState(() {
        _selectedTap = tapCode;
        _tapStatus = status;
        _boList = boList;
        _selectedBienSo = boList.isNotEmpty ? boList.first : null;
      });
    } catch (e) {
      _toast('Lỗi load TAP: $e', isError: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_adminUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Tools')),
        body: const Center(child: Text('Chỉ admin được truy cập')),);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedTap,
              decoration: const InputDecoration(labelText: 'Chọn TAP'),
              items: _taps
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                _loadTapContext(val);
              },
            ),
            const SizedBox(height: 12),
            if (_selectedTap != null)
              Row(
                children: [
                  Chip(label: Text('State: ${_tapStatus.value}')),
                  const SizedBox(width: 8),
                  Chip(label: Text('Bộ hồ sơ: ${_boList.length}')),
                ],
              ),
            const SizedBox(height: 16),
            if (_selectedTap != null)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _unlockTap,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unlock TAP'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _reExportZip,
                    icon: const Icon(Icons.folder_zip),
                    label: const Text('Re-export ZIP'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _resetQuota,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset quota'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (_selectedTap != null)
              DropdownButtonFormField<String>(
                value: _selectedBienSo,
                decoration: const InputDecoration(labelText: 'Biển số (PDF)'),
                items: _boList
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBienSo = val),
              ),
            if (_selectedTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _reExportPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Re-export PDF'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlockTap() async {
    if (_selectedTap == null) return;
    setState(() => _busy = true);
    try {
      final currentStatus = await TapService.getTapStatus(_selectedTap!);
      if (currentStatus.isOpen) {
        _toast('TAP đã ở trạng thái OPEN');
        return;
      }
      await TapService.setTapStatus(_selectedTap!, TapStatus.open);
      setState(() => _tapStatus = TapStatus.open);

      final user = await UserService.getCurrentUser();
      await AuditService.logAction(
        tapCode: _selectedTap!,
        userId: user?['user_id'] ?? 'unknown',
        userDisplayName: user?['display_name'] ?? '',
        action: 'ADMIN_UNLOCK',
        eventType: AuditEventType.adminUnlock,
        target: _selectedTap!,
        caseState: TapStatus.open.value,
      );
      _toast('Đã unlock TAP');
    } catch (e) {
      _toast('Lỗi unlock: $e', isError: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _reExportZip() async {
    if (_selectedTap == null) return;
    setState(() => _busy = true);
    try {
      if (_boList.isEmpty) {
        await _loadTapContext(_selectedTap!);
        if (_boList.isEmpty) throw Exception('TAP không có hồ sơ');
      }
      final zipPath = await ZipService.zipTap(
        _selectedTap!,
        zipName: _boList.first,
        adminOverride: true,
      );
      final user = await UserService.getCurrentUser();
      await AuditService.logAction(
        tapCode: _selectedTap!,
        userId: user?['user_id'] ?? 'unknown',
        userDisplayName: user?['display_name'] ?? '',
        action: AuditEventType.exportZipAdmin,
        eventType: AuditEventType.exportZipAdmin,
        target: zipPath.split('/').last,
        caseState: _tapStatus.value,
      );
      _toast('Re-export ZIP thành công');
    } catch (e) {
      _toast('ZIP lỗi: $e', isError: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _reExportPdf() async {
    if (_selectedTap == null || _selectedBienSo == null) return;
    setState(() => _busy = true);
    try {
      final file = await PdfService.generateDocumentPdf(
        bienSo: _selectedBienSo!,
        tapCode: _selectedTap!,
        adminOverride: true,
      );
      final user = await UserService.getCurrentUser();
      await AuditService.logAction(
        tapCode: _selectedTap!,
        userId: user?['user_id'] ?? 'unknown',
        userDisplayName: user?['display_name'] ?? '',
        action: AuditEventType.exportPdfAdmin,
        eventType: AuditEventType.exportPdfAdmin,
        target: file.path.split('/').last,
        caseState: _tapStatus.value,
      );
      _toast('Re-export PDF thành công');
    } catch (e) {
      _toast('PDF lỗi: $e', isError: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _resetQuota() async {
    setState(() => _busy = true);
    try {
      final user = await UserService.getCurrentUser();
      await QuotaService.resetQuota(
        adminUserId: user?['user_id'] ?? 'unknown',
        adminDisplayName: user?['display_name'],
      );
      _toast('Đã reset quota');
    } catch (e) {
      _toast('Reset quota lỗi: $e', isError: true);
    } finally {
      setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }
}
