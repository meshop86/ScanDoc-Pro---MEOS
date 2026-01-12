import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/database.dart' as db;
import '../home/case_providers.dart';
import '../home/hierarchy_providers.dart' hide databaseProvider;
import '../../../../scan/vision_scan_service.dart';
import '../../services/storage/image_storage_service.dart';

/// Phase 21.FIX: Single QScan case ID (fixed UUID)
const _kQScanCaseId = 'qscan-00000000-0000-0000-0000-000000000001';
const _kQScanCaseName = 'QScan';

/// Phase 13.1: Quick Scan (QSCan)
/// 
/// Fast scanning flow:
/// 1. Opens scan engine immediately (no prompts)
/// 2. User scans multiple pages continuously  
/// 3. All pages auto-saved to default "QSCan" case
/// 4. User names/organizes pages AFTER scanning
/// 
/// Phase 16: Image Persistence
/// - Copies scanned images from temp to persistent storage
/// - Updates Page.imagePath to persistent location
class QuickScanScreen extends ConsumerStatefulWidget {
  const QuickScanScreen({super.key});

  @override
  ConsumerState<QuickScanScreen> createState() => _QuickScanScreenState();
}

class _QuickScanScreenState extends ConsumerState<QuickScanScreen> {
  bool _isScanning = false;
  final List<String> _scannedPages = [];

  @override
  void initState() {
    super.initState();
    // Phase 21.FIX: Reset state on each screen open
    _scannedPages.clear();
  }

  Future<void> _startScanning() async {
    setState(() => _isScanning = true);
    
    try {
      // Launch VisionScanService (existing scan engine - FROZEN)
      final imagePaths = await VisionScanService.scanDocument();
      
      if (imagePaths != null && imagePaths.isNotEmpty) {
        setState(() {
          _scannedPages.addAll(imagePaths);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scanned ${imagePaths.length} page(s)'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else if (mounted) {
        // User cancelled or no pages
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Quick Scan error: $e');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _finishScanning() async {
    if (_scannedPages.isEmpty) {
      Navigator.pop(context);
      return;
    }

    try {
      setState(() => _isScanning = true);
      
      final database = ref.read(databaseProvider);
      
      // Phase 21.FIX: Ensure single QScan case (by fixed ID)
      db.Case? qscanCase;
      
      // Try to get QScan case by fixed ID
      qscanCase = await database.getCase(_kQScanCaseId);
      
      // Create QScan case if doesn't exist
      if (qscanCase == null) {
        await database.createCase(
          db.CasesCompanion(
            id: const drift.Value(_kQScanCaseId), // Fixed UUID
            name: const drift.Value(_kQScanCaseName),
            description: const drift.Value('Quick Scan documents'),
            status: const drift.Value('active'),
            createdAt: drift.Value(DateTime.now()),
            ownerUserId: const drift.Value('default'),
            // Phase 21: Regular case, top-level
            isGroup: const drift.Value(false),
            parentCaseId: const drift.Value(null),
          ),
        );
        
        // Fetch the created case to confirm it exists
        qscanCase = await database.getCase(_kQScanCaseId);
        if (qscanCase == null) {
          throw Exception('Failed to create QScan case');
        }
        print('✓ Created QScan case: $_kQScanCaseId');
      } else {
        print('✓ Using existing QScan case: $_kQScanCaseId');
      }
      
      // 2. Create Page records for each scanned image
      // Phase 16: Copy images to persistent storage first
      print('📦 Copying ${_scannedPages.length} images to persistent storage...');
      final copyResults = await ImageStorageService.copyImagesToPersistentStorage(_scannedPages);
      
      int pageNumber = 1;
      int successCount = 0;
      int failCount = 0;
      
      for (final tempPath in _scannedPages) {
        final persistentPath = copyResults[tempPath];
        
        if (persistentPath == null) {
          print('⚠️ Failed to copy image, skipping page $pageNumber');
          failCount++;
          pageNumber++;
          continue;
        }
        
        final pageId = const Uuid().v4(); // Phase 21: UUID v4
        final now = DateTime.now();
        
        // Create page with PERSISTENT path (not temp)
        await database.createPage(
          db.PagesCompanion(
            id: drift.Value(pageId),
            caseId: drift.Value(qscanCase.id),
            name: drift.Value('Page $pageNumber'),
            imagePath: drift.Value(persistentPath), // ← PERSISTENT PATH
            status: const drift.Value('active'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        
        print('✓ Created page: Page $pageNumber (persistent storage)');
        successCount++;
        pageNumber++;
      }
      
      if (mounted) {
        final message = failCount > 0
            ? '✓ Saved $successCount page(s) to QScan ($failCount failed)'
            : '✓ Saved $successCount page(s) to QScan';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Phase 21.FIX: Clear local state after save
        setState(() {
          _scannedPages.clear();
        });
        
        // Phase 21.FIX: Refresh providers BEFORE navigation
        ref.invalidate(caseListProvider);
        await ref.read(homeScreenCasesProvider.notifier).refresh();
        
        // Phase 21.FIX v3: Invalidate pages provider for QScan case
        // This ensures case detail screen shows new pages immediately
        ref.invalidate(pagesByCaseProvider(_kQScanCaseId));
        ref.invalidate(caseByIdProvider(_kQScanCaseId));
        
        // Wait a frame for providers to propagate
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Navigate to Home tab using GoRouter
        if (mounted) {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Save error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error saving pages: $e');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Scan'),
        actions: [
          if (_scannedPages.isNotEmpty)
            TextButton(
              onPressed: _finishScanning,
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Scan count banner
          if (_scannedPages.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    '${_scannedPages.length} page(s) scanned',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

          // Scanned pages preview
          if (_scannedPages.isNotEmpty)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _scannedPages.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image, size: 40),
                        const SizedBox(height: 4),
                        Text(
                          'Page ${index + 1}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Quick Scan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan documents fast without setup',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _isScanning ? null : _startScanning,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt),
                      label: Text(_isScanning ? 'Scanning...' : 'Start Scanning'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _scannedPages.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isScanning ? null : _startScanning,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Scan More'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _finishScanning,
                        icon: const Icon(Icons.check),
                        label: const Text('Finish'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
