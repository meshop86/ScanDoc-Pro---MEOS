import 'dart:io';

import '../../data/database/database.dart';
import '../storage/image_storage_service.dart';

/// Phase 21.3: Delete Guard
///
/// Enforces delete operation constraints for case hierarchy.
///
/// Delete Strategy:
/// - Group Cases: REQUIRE EMPTY (no children) before delete
/// - Regular Cases: Cascade delete all content (pages, exports, folders)
class DeleteGuard {
  /// Delete case with cascade handling
  ///
  /// For Group Cases:
  /// - Prevents deletion if children exist (require empty)
  ///
  /// For Regular Cases:
  /// - Deletes all pages (and image files)
  /// - Deletes all exports (and export files)
  /// - Deletes all folders
  /// - Finally deletes the case
  static Future<void> deleteCase(
    AppDatabase db,
    String caseId,
  ) async {
    final caseData = await db.getCase(caseId);
    if (caseData == null) return;

    if (caseData.isGroup) {
      // Group case: must be empty before delete
      final childCases = await db.getChildCases(caseId);

      if (childCases.isNotEmpty) {
        throw Exception(
          'Cannot delete group: contains ${childCases.length} case(s). '
          'Move or delete child cases first.',
        );
      }

      // Group is empty, safe to delete
      await db.deleteCase(caseId);
      print('✅ Deleted empty group case: ${caseData.name}');
    } else {
      // Regular case: cascade delete all content

      // 1. Delete pages and image files
      final pages = await db.getPagesByCase(caseId);
      for (final page in pages) {
        // Delete image files
        await ImageStorageService.deleteImage(page.imagePath);
        if (page.thumbnailPath != null) {
          await ImageStorageService.deleteImage(page.thumbnailPath!);
        }

        await db.deletePage(page.id);
      }
      print('✅ Deleted ${pages.length} page(s)');

      // 2. Delete exports and export files
      final exports = await db.getExportsByCase(caseId);
      for (final export in exports) {
        // Delete export file from disk
        try {
          final file = File(export.filePath);
          if (await file.exists()) {
            await file.delete();
            print('✅ Deleted export file: ${export.fileName}');
          }
        } catch (e) {
          print('⚠️ Failed to delete export file: ${export.fileName} - $e');
        }

        await db.deleteExport(export.id);
      }
      print('✅ Deleted ${exports.length} export(s)');

      // 3. Delete folders
      final folders = await db.getFoldersByCase(caseId);
      for (final folder in folders) {
        await db.deleteFolder(folder.id);
      }
      print('✅ Deleted ${folders.length} folder(s)');

      // 4. Finally, delete the case
      await db.deleteCase(caseId);
      print('✅ Deleted case: ${caseData.name}');
    }
  }

  /// Check if group case can be deleted
  ///
  /// Returns true if group is empty (no children)
  static Future<bool> canDeleteGroupCase(
    AppDatabase db,
    String caseId,
  ) async {
    final caseData = await db.getCase(caseId);
    if (caseData == null || !caseData.isGroup) {
      return false;
    }

    final childCases = await db.getChildCases(caseId);
    return childCases.isEmpty;
  }
}
