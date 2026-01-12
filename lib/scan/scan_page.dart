import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'vision_scan_service.dart';
import 'scan_file_service.dart';
import 'zip_service.dart';
import 'manifest_service.dart';
import 'tap_service.dart';
import 'audit_events.dart';
import 'tap_status.dart';
import 'audit_service.dart';
import 'user_service.dart';
import 'label_model.dart';

/// Document type model
class DocumentType {
  final String code;
  final String label;
  final bool required;

  DocumentType({
    required this.code,
    required this.label,
    required this.required,
  });
}

/// Scan Page - Quản lý file hồ sơ (multi-page)
class ScanPage extends StatefulWidget {
  final String bienSo;
  final String? tapCode;
  final bool adminUnlocked;

  const ScanPage({
    super.key,
    required this.bienSo,
    this.tapCode,
    this.adminUnlocked = false,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // Danh sách giấy tờ (chỉ giữ to_khai, nguon_goc)
  List<DocumentType> documentTypes = [
    DocumentType(code: 'to_khai', label: 'Tờ khai (*)', required: true),
    DocumentType(code: 'nguon_goc', label: 'Nguồn gốc', required: false),
  ];

  String? _selectedDocType;
  bool _scanning = false;
  bool _zipping = false;
  bool _multiPageMode = false; // Toggle multi-page
  TapStatus _tapStatus = TapStatus.open;
  UserInfo? _currentUser;
  Map<String, String> _documentLabels = {};
  bool get _canEditLabels => _isOpen || widget.adminUnlocked;
  
  // Multi-page state
  List<File> _tempPages = []; // Preview pages before save
  Map<String, List<File>> _savedPages = {}; // Saved pages per docType

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final pages = await _collectSavedPages();
    final user = await _loadUserInfo();
    final labels = await ManifestService.readDocumentUserLabels(widget.bienSo, tapCode: widget.tapCode);
    TapStatus status = _tapStatus;
    if (widget.tapCode != null) {
      status = await TapService.getTapStatus(widget.tapCode!);
    }

    if (mounted) {
      setState(() {
        _savedPages = pages;
        _currentUser = user;
        _tapStatus = status;
        _documentLabels = labels;
      });
    }
  }

  Future<Map<String, List<File>>> _collectSavedPages() async {
    final pages = <String, List<File>>{};
    for (var docType in documentTypes) {
      final docPages = await ScanFileService.getDocumentPages(
        widget.bienSo,
        docType.code,
        tapCode: widget.tapCode,
      );
      if (docPages.isNotEmpty) {
        pages[docType.code] = docPages;
      }
    }
    return pages;
  }

  Future<void> _reloadPages() async {
    final pages = await _collectSavedPages();
    TapStatus status = _tapStatus;
    if (widget.tapCode != null) {
      status = await TapService.getTapStatus(widget.tapCode!);
    }

    if (mounted) {
      setState(() {
        _savedPages = pages;
        _tapStatus = status;
      });
    }
  }

  Future<void> _scan() async {
    if (_blockIfNotOpen()) return;
    if (_selectedDocType == null) {
      _showError('Vui lòng chọn loại giấy tờ');
      return;
    }

    setState(() => _scanning = true);

    try {
      // Scan từ VisionKit
      final tempPaths = await VisionScanService.scanDocument();
      if (tempPaths == null || tempPaths.isEmpty) {
        if (mounted) {
          setState(() => _scanning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy scan')),
          );
        }
        return;
      }

      // Nếu không bật multi-page, lưu ngay 1 trang đầu tiên
      if (!_multiPageMode) {
        await ScanFileService.saveScannedFiles(
          tempFilePaths: [tempPaths.first],
          bienSo: widget.bienSo,
          docType: _selectedDocType!,
          tapCode: widget.tapCode,
        );
        await _logAction(
          'SCAN',
          '${widget.bienSo}/${_selectedDocType}_p1.jpg',
          eventType: AuditEventType.scan,
        );
        await _reloadPages();
        if (mounted) {
          setState(() {
            _scanning = false;
            _selectedDocType = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Lưu 1 trang'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        return;
      }

      // Multi-page mode: load temp pages for preview
      final tempPageFiles = tempPaths.map((p) => File(p)).toList();
      
      if (mounted) {
        setState(() {
          _tempPages = tempPageFiles;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        _showError('Lỗi: $e');
      }
    }
  }

  Future<void> _retakePage(int pageIndex) async {
    if (_blockIfNotOpen()) return;
    if (_selectedDocType == null) return;

    setState(() => _scanning = true);

    try {
      final tempPaths = await VisionScanService.scanDocument();
      if (tempPaths == null || tempPaths.isEmpty) {
        if (mounted) setState(() => _scanning = false);
        return;
      }

      // Replace page at index
      if (mounted) {
        setState(() {
          if (pageIndex < _tempPages.length) {
            _tempPages[pageIndex] = File(tempPaths.first);
          }
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        _showError('Lỗi: $e');
      }
    }
  }

  void _deletePage(int pageIndex) {
    if (_blockIfNotOpen()) return;
    setState(() {
      if (pageIndex < _tempPages.length) {
        _tempPages.removeAt(pageIndex);
      }
    });
  }

  Future<void> _savePage() async {
    if (_selectedDocType == null || _tempPages.isEmpty) {
      _showError('Đời chọn giấy tờ và scan ít nhất 1 trang');
      return;
    }

    if (_blockIfNotOpen()) return;

    try {
      final docType = _selectedDocType!;
      // Convert temp files to paths
      final tempPaths = _tempPages.map((f) => f.path).toList();
      final savedCount = tempPaths.length;

      // Save to final location
      await ScanFileService.saveScannedFiles(
        tempFilePaths: tempPaths,
        bienSo: widget.bienSo,
        docType: docType,
        tapCode: widget.tapCode,
      );

      // Reload saved pages
      for (int i = 0; i < tempPaths.length; i++) {
        await _logAction(
          'SCAN',
          '${widget.bienSo}/${docType}_${widget.bienSo}_p${i + 1}.jpg',
          eventType: AuditEventType.scan,
        );
      }
      await _reloadPages();

      if (mounted) {
        setState(() {
          _tempPages.clear();
          _selectedDocType = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Lưu $savedCount trang'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError('Lỗi lưu: $e');
    }
  }

  Future<void> _deleteDocument() async {
    if (_blockIfNotOpen()) return;
    if (_selectedDocType == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giấy tờ'),
        content: Text('Xóa tất cả trang của ${_selectedDocType}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ScanFileService.deleteDocument(
        widget.bienSo,
        _selectedDocType!,
        tapCode: widget.tapCode,
      );
      await _logAction(
        'DELETE',
        '${widget.bienSo}/${_selectedDocType}',
        eventType: AuditEventType.deleteBo,
      );
      await _reloadPages();

      if (mounted) {
        setState(() {
          _selectedDocType = null;
          _tempPages.clear();
        });
      }
    }
  }

  /// Thêm giấy tờ phát sinh (custom)
  Future<void> _addCustomDocType() async {
    if (_blockIfNotOpen()) return;
    final controller = TextEditingController(text: 'Giấy tờ phát sinh');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm giấy tờ'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tên giấy tờ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Tạo code từ tên (lowercase, no spaces)
      final code = result.toLowerCase().replaceAll(' ', '_');
      setState(() {
        documentTypes.add(DocumentType(code: code, label: result, required: false));
        _selectedDocType = code;
      });
    }
  }

  bool get _isOpen => widget.tapCode == null || _tapStatus.isOpen;

  bool _blockIfNotOpen() {
    if (_isOpen) return false;
    final msg = _tapStatus.isLocked
        ? 'TAP đang LOCKED, không thể scan hoặc sửa ảnh'
        : 'TAP không ở trạng thái OPEN';
    _showError(msg);
    return true;
  }

  Future<void> _logAction(String action, String target, {String? eventType}) async {
    if (widget.tapCode == null) return;
    final user = _currentUser ?? await _loadUserInfo();
    _currentUser = user;
    await AuditService.logAction(
      tapCode: widget.tapCode!,
      userId: user.userId,
      userDisplayName: user.displayName,
      action: action,
      eventType: eventType ?? action,
      target: target,
      caseState: _tapStatus.value,
    );
  }

  Future<UserInfo> _loadUserInfo() async {
    final userMap = await UserService.getCurrentUser();
    if (userMap == null) {
      return const UserInfo(userId: 'unknown_user', displayName: 'Unknown');
    }
    return UserInfo(
      userId: userMap['user_id'] ?? 'unknown_user',
      displayName: userMap['display_name'] ?? 'Unknown',
    );
  }

  Future<void> _updateDocumentLabel(String key, String value) async {
    final oldValue = _documentLabels[key];
    if (oldValue == value) return;
    if (!_canEditLabels) {
      _showError('Chỉ chỉnh label khi OPEN hoặc admin đã unlock');
      return;
    }

    try {
      final user = await _loadUserInfo();
      final newLabels = Map<String, String>.from(_documentLabels)..[key] = value;
      await ManifestService.writeManifest(
        bienSo: widget.bienSo,
        userInfo: user,
        tapCode: widget.tapCode,
        userLabels: newLabels,
      );
      setState(() {
        _documentLabels = newLabels;
      });

      await _logAction(
        'LABEL_SET_DOC',
        '${widget.bienSo}:$key:${oldValue ?? ''}->${value}',
        eventType: AuditEventType.labelSetDoc,
      );
      _showSuccess('Đã gán nhãn');
    } catch (e) {
      _showError('Lỗi lưu label: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  Future<void> _zipAndShare(BuildContext ctx) async {
    if (_blockIfNotOpen()) return;
    // Kiểm tra có dữ liệu không
    final hasFiles = _savedPages.values.any((pages) => pages.isNotEmpty);
    if (!hasFiles) {
      _showError('Hồ sơ trống, chưa có ảnh');
      return;
    }

    setState(() => _zipping = true);
    try {
      final user = await _loadUserInfo();
      await ManifestService.writeManifest(
        bienSo: widget.bienSo,
        userInfo: user,
        tapCode: widget.tapCode,
        userLabels: _documentLabels,
      );

      // ZIP depends on context: individual or TAP
      String zipPath;
      if (widget.tapCode != null) {
        // When trong TAP: không share lẻ, yêu cầu quay lại TAP để hoàn tất/LOCK
        if (mounted) {
          setState(() => _zipping = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đang ở TAP: không share lẻ. Quay lại TAP để hoàn tất & LOCK.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      } else {
        // Standalone mode: zip single bo ho so
        zipPath = await ZipService.zipHoso(widget.bienSo);
      }

      if (!mounted) return;
      setState(() => _zipping = false);

      final renderBox = ctx.findRenderObject() as RenderBox?;
      if (renderBox == null || renderBox.size.isEmpty) {
        _showError('Không xác định được vị trí share');
        return;
      }
      final origin = renderBox.localToGlobal(Offset.zero) & renderBox.size;

      await Share.shareXFiles(
        [XFile(zipPath)],
        text: 'HoSoXe ${widget.bienSo}',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _zipping = false);
        _showError('ZIP lỗi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hồ sơ: ${widget.bienSo}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị biển số
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.drive_eta, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Biển số: ${widget.bienSo}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.tapCode != null) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(widget.tapCode!),
                        backgroundColor: Colors.orange.shade100,
                        labelStyle: const TextStyle(fontSize: 12),
                      ),
                      if (!_isOpen) ...[
                        const SizedBox(width: 8),
                        Chip(
                          avatar: const Icon(Icons.lock, size: 16, color: Colors.red),
                          label: Text(_tapStatus.value),
                          backgroundColor: Colors.red.shade50,
                          labelStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Document labels (biển số)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nhãn hồ sơ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: LabelPresets.documentUserLabels.map((opt) {
                        final current = _documentLabels[opt.key];
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
                                  if (val != null) _updateDocumentLabel(opt.key, val);
                                } : null,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    if (!_canEditLabels)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Label chỉ chỉnh khi OPEN hoặc admin unlock.',
                          style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Hoàn tất & Gửi hồ sơ
            if (_savedPages.values.any((pages) => pages.isNotEmpty))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _zipping || !_isOpen ? null : () => _zipAndShare(context),
                  icon: _zipping
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.ios_share),
                  label: Text(_zipping
                      ? 'Đang lưu manifest...'
                      : (widget.tapCode != null
                          ? 'Lưu manifest'
                          : 'Hoàn tất & Gửi hồ sơ')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (_savedPages.values.any((pages) => pages.isNotEmpty))
              const SizedBox(height: 24),

            // Danh sách giấy tờ
            Text(
              'Giấy tờ cần scan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            ...documentTypes.map((docType) {
              final savedCount = _savedPages[docType.code]?.length ?? 0;
              final isSelected = _selectedDocType == docType.code;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDocType = docType.code);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected ? Colors.blue.shade50 : Colors.white,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: savedCount > 0
                                ? Colors.green
                                : Colors.grey.shade200,
                          ),
                          child: Center(
                            child: Text(
                              savedCount > 0 ? '✓' : '○',
                              style: TextStyle(
                                color: savedCount > 0
                                    ? Colors.white
                                    : Colors.grey,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(docType.label),
                              if (savedCount > 0)
                                Text(
                                  '$savedCount trang',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            // Nút thêm giấy tờ phát sinh
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: !_isOpen ? null : _addCustomDocType,
                icon: const Icon(Icons.add),
                label: const Text('Thêm giấy tờ'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.blue.shade300),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Toggle multi-page mode
            if (_selectedDocType != null)
              Row(
                children: [
                  Checkbox(
                    value: _multiPageMode,
                    onChanged: !_isOpen
                        ? null
                        : (val) => setState(() => _multiPageMode = val ?? false),
                  ),
                  const Text('Chụp nhiều trang'),
                ],
              ),

            const SizedBox(height: 12),

            // Chế độ xem: Saved hoặc Preview
            if (_selectedDocType != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  if (_tempPages.isNotEmpty) ...[
                    // Preview temp pages (chế độ chỉnh sửa)
                    ..._tempPages.asMap().entries.map((e) {
                      final index = e.key;
                      final page = e.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 250,
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  page,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _scanning
                                      ? null
                                      : (!_isOpen ? null : () => _retakePage(index)),
                                    icon: const Icon(Icons.refresh),
                                    label:
                                        Text('Chụp lại trang ${index + 1}'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: !_isOpen ? null : () => _deletePage(index),
                                  icon: const Icon(Icons.delete),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  label: const Text('Xóa'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _scanning || !_isOpen ? null : _scan,
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm trang'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _tempPages.isEmpty || !_isOpen ? null : _savePage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            icon: const Icon(Icons.save),
                            label: const Text('Lưu'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_savedPages.containsKey(_selectedDocType) &&
                      _savedPages[_selectedDocType]!.isNotEmpty) ...[
                    // Preview saved pages
                    ..._savedPages[_selectedDocType]!.asMap().entries.map((e) {
                      final index = e.key;
                      final page = e.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 250,
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  page,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _scanning
                                      ? null
                                      : (!_isOpen ? null : () => _retakePage(index)),
                                    icon: const Icon(Icons.refresh),
                                    label: Text(
                                      'Chụp lại trang ${index + 1}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _scanning || !_isOpen ? null : _scan,
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm trang'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: !_isOpen ? null : _deleteDocument,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          icon: const Icon(Icons.delete),
                          label: const Text('Xóa'),
                        ),
                      ],
                    ),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Text(
                              'Chưa có ảnh',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _scanning || !_isOpen ? null : _scan,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Chụp & Scan'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
