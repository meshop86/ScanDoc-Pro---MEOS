import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// DocumentSetService – generalized document management for ScanDoc Pro
/// Handles Document Set (user-named collections) with slug-based storage
/// Maintains backward compatibility with legacy bien_so naming
class DocumentSetService {
  /// Convert user-friendly name to URL-friendly slug
  /// Example: "Biển Số XE 14BX-4524" → "bien_so_xe_14bx4524"
  static String toSlug(String displayName) {
    return displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')  // Remove special chars
        .replaceAll(RegExp(r'\s+'), '_')        // Spaces to underscores
        .replaceAll(RegExp(r'_+'), '_')         // Multiple underscores to single
        .replaceAll(RegExp(r'-+'), '')          // Remove dashes
        .replaceAll(RegExp(r'_$'), '');         // Remove trailing underscore
  }

  /// Check if identifier looks like legacy bien_so format (alphanumeric, maybe dash)
  /// Example: "14BX-4524" → true, "bien_so_xe_14bx4524" → false
  static bool isLegacyFormat(String identifier) {
    // Legacy: alphanumeric + optional dash, NO underscores
    return !identifier.contains('_') && RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(identifier);
  }

  /// Get document folder path for a document set within a case
  /// Supports both legacy (bien_so) and generalized (slug) formats
  static Future<Directory> getDocumentSetDirectory({
    required String caseId,
    required String documentSetSlug,
    String? tapCode,  // Legacy: TAP compatibility
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final casesRoot = '${docsDir.path}/HoSoXe';  // Keep root name for compatibility
    
    final pathSegments = [casesRoot];
    if (tapCode != null) pathSegments.add(tapCode);
    pathSegments.add(caseId);
    pathSegments.add(documentSetSlug);
    
    final path = pathSegments.join('/');
    final dir = Directory(path);
    
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return dir;
  }

  /// Build image filename for a page in a document set
  /// Single page: documentSetSlug.jpg
  /// Multi-page: documentSetSlug_pN.jpg
  static String buildPageFilename({
    required String documentSetSlug,
    required int pageNumber,
    bool singlePage = false,
  }) {
    if (singlePage) return '$documentSetSlug.jpg';
    return '${documentSetSlug}_p$pageNumber.jpg';
  }

  /// Parse page number from filename
  /// Handles both: "set_slug_p5.jpg" → 5, "set_slug.jpg" → 1
  static int parsePageNumber(String filename, String setSlug) {
    if (filename == '$setSlug.jpg') return 1;
    
    final pattern = RegExp(r'_p(\d+)\.jpg$');
    final match = pattern.firstMatch(filename);
    return int.tryParse(match?.group(1) ?? '1') ?? 1;
  }

  /// List all pages of a document set in order
  static Future<List<File>> listDocumentPages({
    required String caseId,
    required String documentSetSlug,
    String? tapCode,
  }) async {
    final dir = await getDocumentSetDirectory(
      caseId: caseId,
      documentSetSlug: documentSetSlug,
      tapCode: tapCode,
    );
    
    if (!await dir.exists()) return [];
    
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final name = f.path.split('/').last.toLowerCase();
          // Match single-page or multi-page pattern
          return name == '$documentSetSlug.jpg' ||
                 name.startsWith('${documentSetSlug}_p') && name.endsWith('.jpg');
        })
        .toList();
    
    // Sort by page number
    files.sort((a, b) {
      final aNum = parsePageNumber(a.path.split('/').last, documentSetSlug);
      final bNum = parsePageNumber(b.path.split('/').last, documentSetSlug);
      return aNum.compareTo(bNum);
    });
    
    return files;
  }

  /// Delete a specific page
  static Future<void> deletePage({
    required String caseId,
    required String documentSetSlug,
    required int pageNumber,
    String? tapCode,
  }) async {
    final dir = await getDocumentSetDirectory(
      caseId: caseId,
      documentSetSlug: documentSetSlug,
      tapCode: tapCode,
    );
    
    final filename = buildPageFilename(
      documentSetSlug: documentSetSlug,
      pageNumber: pageNumber,
    );
    
    final file = File('${dir.path}/$filename');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Delete entire document set
  static Future<void> deleteDocumentSet({
    required String caseId,
    required String documentSetSlug,
    String? tapCode,
  }) async {
    final dir = await getDocumentSetDirectory(
      caseId: caseId,
      documentSetSlug: documentSetSlug,
      tapCode: tapCode,
    );
    
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Rename document set (updates folder + file internal references)
  static Future<void> renameDocumentSet({
    required String caseId,
    required String oldSlug,
    required String newSlug,
    String? tapCode,
  }) async {
    final oldDir = await getDocumentSetDirectory(
      caseId: caseId,
      documentSetSlug: oldSlug,
      tapCode: tapCode,
    );
    
    final newDir = await getDocumentSetDirectory(
      caseId: caseId,
      documentSetSlug: newSlug,
      tapCode: tapCode,
    );
    
    if (!await oldDir.exists()) {
      throw Exception('Document set tidak tồn tại: $oldSlug');
    }
    
    if (await newDir.exists()) {
      throw Exception('Tên document set mới đã tồn tại: $newSlug');
    }
    
    try {
      await oldDir.rename(newDir.path);
      
      // Rename internal files if old/new slug differ
      if (oldSlug != newSlug) {
        final files = await listDocumentPages(
          caseId: caseId,
          documentSetSlug: newSlug,
          tapCode: tapCode,
        );
        
        for (final file in files) {
          final oldName = file.path.split('/').last;
          final pageNum = parsePageNumber(oldName, newSlug);
          
          // Rebuild filename with new slug
          final newName = buildPageFilename(
            documentSetSlug: newSlug,
            pageNumber: pageNum,
          );
          
          if (oldName != newName) {
            final newFile = File('${newDir.path}/$newName');
            await file.rename(newFile.path);
          }
        }
      }
    } catch (e) {
      print('Rename document set failed: $e');
      rethrow;
    }
  }
}
