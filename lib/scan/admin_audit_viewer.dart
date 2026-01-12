import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'audit_events.dart';
import 'tap_service.dart';
import 'user_service.dart';

class AdminAuditViewerPage extends StatefulWidget {
  const AdminAuditViewerPage({super.key});

  @override
  State<AdminAuditViewerPage> createState() => _AdminAuditViewerPageState();
}

class _AdminAuditViewerPageState extends State<AdminAuditViewerPage> {
  List<String> _tapCodes = [];
  String _selectedTap = 'ALL';
  String _selectedEvent = 'ALL';
  bool _sortDesc = true;
  bool _loading = true;
  List<_AuditEntry> _entries = [];
  bool _adminUnlocked = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final admin = await UserService.isAdminUnlocked();
    final taps = await TapService.listTaps();
    setState(() {
      _adminUnlocked = admin;
      _tapCodes = taps;
    });
    if (admin) {
      await _loadEntries();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final targets = _selectedTap == 'ALL' ? _tapCodes : [_selectedTap];
      final List<_AuditEntry> items = [];

      for (final tap in targets) {
        final file = File('${docs.path}/HoSoXe/$tap/audit_log.json');
        if (!await file.exists()) continue;
        final raw = await file.readAsString();
        final parsed = jsonDecode(raw);
        if (parsed is! List) continue;
        for (final e in parsed) {
          if (e is! Map) continue;
          final entry = _AuditEntry.fromJson(e, fallbackTap: tap);
          if (_selectedEvent != 'ALL' && entry.eventType != _selectedEvent) {
            continue;
          }
          items.add(entry);
        }
      }

      items.sort((a, b) => _sortDesc
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp));

      setState(() {
        _entries = items;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đọc audit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_adminUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit Viewer')), 
        body: const Center(child: Text('Chỉ admin mới xem được audit')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Viewer'),
        actions: [
          IconButton(
            icon: Icon(_sortDesc ? Icons.arrow_downward : Icons.arrow_upward),
            onPressed: () {
              setState(() => _sortDesc = !_sortDesc);
              _loadEntries();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(child: _buildTapFilter()),
                      const SizedBox(width: 8),
                      Expanded(child: _buildEventFilter()),
                    ],
                  ),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(child: Text('Không có audit phù hợp'))
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (ctx, idx) {
                            final e = _entries[idx];
                            return ListTile(
                              dense: true,
                              title: Text('${e.eventType} • ${e.tapCode}'),
                              subtitle: Text('${e.timestamp.toIso8601String()}\n${e.userDisplay} (${e.userId})\n${e.target}'),
                              trailing: Text(e.caseState ?? '-'),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTapFilter() {
    final items = ['ALL', ..._tapCodes];
    return DropdownButtonFormField<String>(
      value: _selectedTap,
      decoration: const InputDecoration(labelText: 'TAP'),
      items: items
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (val) {
        if (val == null) return;
        setState(() => _selectedTap = val);
        _loadEntries();
      },
    );
  }

  Widget _buildEventFilter() {
    final types = [
      'ALL',
      AuditEventType.adminUnlock,
      AuditEventType.labelSetTap,
      AuditEventType.labelSetDoc,
      AuditEventType.deleteBo,
      AuditEventType.renameBo,
      AuditEventType.finalizeTap,
      AuditEventType.exportZip,
      AuditEventType.exportZipAdmin,
      AuditEventType.exportPdf,
      AuditEventType.exportPdfAdmin,
      AuditEventType.scan,
    ];
    return DropdownButtonFormField<String>(
      value: _selectedEvent,
      decoration: const InputDecoration(labelText: 'Event type'),
      items: types
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (val) {
        if (val == null) return;
        setState(() => _selectedEvent = val);
        _loadEntries();
      },
    );
  }
}

class _AuditEntry {
  final String tapCode;
  final String eventType;
  final String userId;
  final String userDisplay;
  final String target;
  final String? caseState;
  final DateTime timestamp;

  _AuditEntry({
    required this.tapCode,
    required this.eventType,
    required this.userId,
    required this.userDisplay,
    required this.target,
    required this.timestamp,
    this.caseState,
  });

  factory _AuditEntry.fromJson(Map<dynamic, dynamic> json, {required String fallbackTap}) {
    final timeStr = json['time']?.toString();
    DateTime ts;
    try {
      ts = DateTime.parse(timeStr ?? '');
    } catch (_) {
      ts = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final event = json['event_type']?.toString() ?? json['action']?.toString() ?? 'UNKNOWN';
    final userDisplay = json['user_display']?.toString();
    return _AuditEntry(
      tapCode: json['tap_code']?.toString() ?? fallbackTap,
      eventType: event,
      userId: json['user']?.toString() ?? 'unknown',
      userDisplay: userDisplay != null && userDisplay.isNotEmpty ? userDisplay : 'Unknown',
      target: json['target']?.toString() ?? '',
      caseState: json['case_state']?.toString(),
      timestamp: ts,
    );
  }
}
