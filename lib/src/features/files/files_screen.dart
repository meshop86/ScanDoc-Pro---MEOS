import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../data/database/database.dart' as db;
import '../../routing/routes.dart';
import '../home/case_providers.dart';
import '../../services/export/export_service.dart';

// Provider for exports list
final exportsListProvider = StreamProvider.autoDispose<List<db.Export>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.getAllExports().asStream();
});

/// Phase 20: Files view - shows exported files (PDF/ZIP)
/// 
/// Before Phase 20: Showed all scanned pages grouped by case
/// After Phase 20: Shows EXPORTED FILES with share/delete actions
class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportsAsync = ref.watch(exportsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exported Files'),
        elevation: 0,
      ),
      body: exportsAsync.when(
        data: (exports) {
          if (exports.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: exports.length,
            itemBuilder: (context, index) {
              final export = exports[index];
              return _ExportFileCard(export: export);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              'No Exported Files',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Export your cases as PDF or ZIP',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the share icon in any case to export',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(Routes.home),
              icon: const Icon(Icons.folder),
              label: const Text('Go to Cases'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card displaying an exported file
class _ExportFileCard extends ConsumerWidget {
  const _ExportFileCard({required this.export});

  final db.Export export;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load case name
    final caseAsync = ref.watch(caseByIdProvider(export.caseId));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: export.fileType == 'PDF' ? Colors.red.shade100 : Colors.blue.shade100,
          child: Icon(
            export.fileType == 'PDF' ? Icons.picture_as_pdf : Icons.folder_zip,
            color: export.fileType == 'PDF' ? Colors.red.shade700 : Colors.blue.shade700,
          ),
        ),
        title: Text(
          export.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            caseAsync.when(
              data: (caseData) => Text(
                'Case: ${caseData?.name ?? 'Unknown'}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              loading: () => Text(
                'Loading...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              error: (_, __) => Text(
                'Case: Unknown',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${ExportService.formatFileSize(export.fileSize)} • ${_formatDate(export.createdAt)}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            if (value == 'share') {
              await _shareExport(context, export);
            } else if (value == 'delete') {
              await _deleteExport(context, ref, export);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.ios_share, size: 20),
                  SizedBox(width: 12),
                  Text('Share'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _shareExport(context, export),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${DateFormat.jm().format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  Future<void> _shareExport(BuildContext context, db.Export export) async {
    try {
      final file = File(export.filePath);
      
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ File not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Phase 20.2: Get screen bounds for iOS share sheet positioning
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await Share.shareXFiles(
        [XFile(export.filePath)],
        subject: export.fileName,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      print('❌ Share error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteExport(BuildContext context, WidgetRef ref, db.Export export) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Export'),
        content: Text('Delete "${export.fileName}"?\\n\\nThis will remove the exported file from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete file from disk
      await ExportService.deleteExportFile(export.filePath);

      // Delete from database
      final database = ref.read(databaseProvider);
      await database.deleteExport(export.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Deleted ${export.fileName}'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Refresh exports list
      ref.invalidate(exportsListProvider);
    } catch (e) {
      print('❌ Delete error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
