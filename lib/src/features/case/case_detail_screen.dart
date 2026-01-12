import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/database.dart' as db;
import '../home/case_providers.dart';
import '../home/hierarchy_providers.dart' hide databaseProvider;
import '../../../../scan/vision_scan_service.dart';
import '../../services/storage/image_storage_service.dart';
import '../../services/export/export_service.dart';

/// Phase 14: New Case Detail Screen (legacy removed)
/// - Shows case name and pages
/// - Actions: view image, rename, delete
/// - Export: simple PDF export from current pages
/// 
/// Phase 15: Case Scan Integration
/// - Added scan button (FloatingActionButton)
/// - Launches VisionScanService with case context
/// - Saves pages directly to this case
/// 
/// Phase 16: Image Persistence
/// - Copies scanned images from temp to persistent storage
/// - Updates Page.imagePath to persistent location
/// 
/// Phase 20: Export Foundation
/// - Added export menu (PDF / ZIP)
/// - Records exports to database
/// - Shows iOS share sheet after export
class CaseDetailScreen extends ConsumerStatefulWidget {
  const CaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen> {
  bool _isScanning = false;

  /// Phase 21.4C: Navigate back to home and expand the parent group
  void _navigateBackToHomeAndExpandGroup(String groupId) {
    // Expand the group in home screen state
    ref.read(homeScreenCasesProvider.notifier).toggleGroup(groupId, forceExpand: true);
    
    // Navigate back to home
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<db.Case?> caseAsync = ref.watch(caseByIdProvider(widget.caseId));
    final AsyncValue<List<db.Page>> pagesAsync = ref.watch(pagesByCaseProvider(widget.caseId));
    final AsyncValue<db.Case?> parentAsync = ref.watch(parentCaseProvider(widget.caseId));

    return Scaffold(
      appBar: AppBar(
        title: caseAsync.when(
          data: (c) => Text(c?.name ?? 'Case'),
          loading: () => const Text('Case'),
          error: (err, st) => const Text('Case'),
        ),
        // Phase 21.4C: Show breadcrumb below title if case has parent
        bottom: parentAsync.when(
          data: (parent) {
            if (parent == null) return null;
            final caseName = caseAsync.value?.name ?? 'Case';
            return PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: _Breadcrumb(
                parentCase: parent,
                currentCaseName: caseName,
                onTapParent: () => _navigateBackToHomeAndExpandGroup(parent.id),
              ),
            );
          },
          loading: () => null,
          error: (_, __) => null,
        ),
        actions: [
          // Phase 20: Export menu (PDF / ZIP)
          PopupMenuButton<String>(
            enabled: pagesAsync.hasValue && (pagesAsync.value?.isNotEmpty ?? false),
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export',
            onSelected: (value) {
              final pages = pagesAsync.value ?? [];
              final caseData = caseAsync.value;
              if (pages.isEmpty || caseData == null) return;
              
              if (value == 'pdf') {
                _exportPDF(caseData, pages);
              } else if (value == 'zip') {
                _exportZIP(caseData, pages);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 20),
                    SizedBox(width: 12),
                    Text('Export as PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'zip',
                child: Row(
                  children: [
                    Icon(Icons.folder_zip, size: 20),
                    SizedBox(width: 12),
                    Text('Export as ZIP'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: pagesAsync.when(
        data: (pages) {
          if (pages.isEmpty) {
            return _EmptyState(caseAsync: caseAsync);
          }
          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(caseByIdProvider(widget.caseId));
              // ignore: unused_result
              ref.refresh(pagesByCaseProvider(widget.caseId));
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: pages.length,
              itemBuilder: (context, index) {
                final page = pages[index];
                return _PageCard(
                  page: page,
                  onView: () => _viewImage(page.imagePath),
                  onRename: () => _renamePage(page),
                  onDelete: () => _deletePage(page),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading pages: $e'),
          ),
        ),
      ),
      floatingActionButton: _isScanning
          ? null
          : FloatingActionButton.extended(
              onPressed: _scanPages,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan'),
              tooltip: 'Scan pages into this case',
            ),
    );
  }

  /// Phase 15: Scan pages directly into this case
  Future<void> _scanPages() async {
    setState(() => _isScanning = true);

    try {
      // Launch VisionScanService (existing scan engine - FROZEN)
      final imagePaths = await VisionScanService.scanDocument();

      if (imagePaths == null || imagePaths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scan cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Save pages to THIS case
      final database = ref.read(databaseProvider);
      final caseData = await ref.read(caseByIdProvider(widget.caseId).future);

      if (caseData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Case not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current page count to continue numbering
      final existingPages = await database.getPagesByCase(widget.caseId);
      int pageNumber = existingPages.length + 1;

      // Phase 16: Copy images to persistent storage first
      print('📦 Copying ${imagePaths.length} images to persistent storage...');
      final copyResults = await ImageStorageService.copyImagesToPersistentStorage(imagePaths);

      // Create page records for each scanned image
      int successCount = 0;
      int failCount = 0;
      
      for (final tempPath in imagePaths) {
        final persistentPath = copyResults[tempPath];
        
        if (persistentPath == null) {
          print('⚠️ Failed to copy image, skipping page $pageNumber');
          failCount++;
          pageNumber++;
          continue;
        }
        
        final pageId = const Uuid().v4();
        final now = DateTime.now();

        await database.createPage(
          db.PagesCompanion(
            id: drift.Value(pageId),
            caseId: drift.Value(widget.caseId),
            name: drift.Value('Page $pageNumber'),
            imagePath: drift.Value(persistentPath), // ← PERSISTENT PATH
            status: const drift.Value('active'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        print('✓ Created page: Page $pageNumber in case ${caseData.name} (persistent storage)');
        successCount++;
        pageNumber++;
      }

      if (mounted) {
        final message = failCount > 0
            ? '✓ Saved $successCount page(s) to ${caseData.name} ($failCount failed)'
            : '✓ Saved $successCount page(s) to ${caseData.name}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh page list to show new pages
        ref.invalidate(pagesByCaseProvider(widget.caseId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Scan error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error scanning pages: $e');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _viewImage(String path) async {
    final file = File(path);
    final exists = await file.exists();
    if (!exists && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found')),
      );
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.file(file, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _renamePage(db.Page page) async {
    final controller = TextEditingController(text: page.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Page'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Page name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    final newName = controller.text.trim();
    if (newName.isEmpty) return;

    final database = ref.read(databaseProvider);
    await database.updatePage(
      db.PagesCompanion(
        id: drift.Value(page.id),
        caseId: drift.Value(page.caseId),
        name: drift.Value(newName),
        imagePath: drift.Value(page.imagePath),
        createdAt: drift.Value(page.createdAt),
        updatedAt: drift.Value(DateTime.now()),
        status: drift.Value(page.status),
        folderId: drift.Value(page.folderId),
        thumbnailPath: drift.Value(page.thumbnailPath),
      ),
    );
    // ignore: unused_result
    ref.refresh(pagesByCaseProvider(page.caseId));
  }

  Future<void> _deletePage(db.Page page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page'),
        content: const Text('This will remove the page from this case.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final database = ref.read(databaseProvider);
      
      // Phase 19: Delete image file BEFORE deleting database record
      try {
        final deleted = await ImageStorageService.deleteImage(page.imagePath);
        if (deleted) {
          print('✓ Deleted image file: ${page.imagePath}');
        } else {
          print('ℹ️ Image file already missing: ${page.imagePath}');
        }
      } catch (e) {
        print('⚠️ Failed to delete image file: $e');
        // Continue with DB deletion even if file deletion fails
      }
      
      // Delete page from database
      await database.deletePage(page.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Page deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      // ignore: unused_result
      ref.refresh(pagesByCaseProvider(page.caseId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting page: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error in _deletePage: $e');
    }
  }

  /// Phase 20: Export case as PDF
  Future<void> _exportPDF(db.Case caseData, List<db.Page> pages) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('Exporting PDF...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get image paths
      final imagePaths = pages.map((p) => p.imagePath).toList();

      // Export PDF
      final filePath = await ExportService.exportPDF(
        caseName: caseData.name,
        imagePaths: imagePaths,
      );

      if (filePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ PDF export failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get file info
      final fileName = filePath.split('/').last;
      final fileSize = await ExportService.getFileSize(filePath);

      // Save to database
      final database = ref.read(databaseProvider);
      final exportId = const Uuid().v4();

      await database.createExport(
        db.ExportsCompanion(
          id: drift.Value(exportId),
          filePath: drift.Value(filePath),
          fileName: drift.Value(fileName),
          fileType: const drift.Value('PDF'),
          caseId: drift.Value(caseData.id),
          fileSize: drift.Value(fileSize),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      print('✓ Export recorded: $exportId');

      // Show share sheet
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // Phase 20.1: Get screen bounds for iOS share sheet positioning
        final box = context.findRenderObject() as RenderBox?;
        final sharePositionOrigin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        
        final result = await Share.shareXFiles(
          [XFile(filePath)],
          subject: '${caseData.name}.pdf',
          sharePositionOrigin: sharePositionOrigin,
        );

        if (result.status == ShareResultStatus.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ Exported: $fileName'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Export PDF error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Phase 20: Export case as ZIP
  Future<void> _exportZIP(db.Case caseData, List<db.Page> pages) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('Exporting ZIP...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get image paths
      final imagePaths = pages.map((p) => p.imagePath).toList();

      // Export ZIP
      final filePath = await ExportService.exportZIP(
        caseName: caseData.name,
        imagePaths: imagePaths,
      );

      if (filePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ ZIP export failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get file info
      final fileName = filePath.split('/').last;
      final fileSize = await ExportService.getFileSize(filePath);

      // Save to database
      final database = ref.read(databaseProvider);
      final exportId = const Uuid().v4();

      await database.createExport(
        db.ExportsCompanion(
          id: drift.Value(exportId),
          filePath: drift.Value(filePath),
          fileName: drift.Value(fileName),
          fileType: const drift.Value('ZIP'),
          caseId: drift.Value(caseData.id),
          fileSize: drift.Value(fileSize),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      print('✓ Export recorded: $exportId');

      // Show share sheet
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // Phase 20.1: Get screen bounds for iOS share sheet positioning
        final box = context.findRenderObject() as RenderBox?;
        final sharePositionOrigin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        
        final result = await Share.shareXFiles(
          [XFile(filePath)],
          subject: '${caseData.name}.zip',
          sharePositionOrigin: sharePositionOrigin,
        );

        if (result.status == ShareResultStatus.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ Exported: $fileName'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Export ZIP error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({required this.page, required this.onView, required this.onRename, required this.onDelete});

  final db.Page page;
  final VoidCallback onView;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FutureBuilder<bool>(
                    future: File(page.imagePath).exists(),
                    builder: (context, snapshot) {
                      final exists = snapshot.data ?? false;
                      if (exists) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(page.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.image_not_supported)),
                          ),
                        );
                      }
                      return const Center(child: Icon(Icons.image_not_supported));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                page.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility),
                    tooltip: 'View',
                  ),
                  IconButton(
                    onPressed: onRename,
                    icon: const Icon(Icons.edit),
                    tooltip: 'Rename',
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase 21.4C: Breadcrumb widget showing "📁 Group Name > 📄 Case Name"
class _Breadcrumb extends StatelessWidget {
  final db.Case parentCase;
  final String currentCaseName;
  final VoidCallback onTapParent;

  const _Breadcrumb({
    required this.parentCase,
    required this.currentCaseName,
    required this.onTapParent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Group name - tappable
          InkWell(
            onTap: onTapParent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📁', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  parentCase.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          
          // Separator
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('>', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          
          // Current case name - not tappable
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📄', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    currentCaseName,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.caseAsync});

  final AsyncValue<db.Case?> caseAsync;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: caseAsync.when(
        data: (c) => Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 24),
              Text(
                c?.name ?? 'Case',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No pages yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the Scan button below to add documents',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.arrow_downward,
                size: 32,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading case',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '$e',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
