import '../../data/database/database.dart';

/// Phase 21.3: Export Guard
///
/// Enforces export operation constraints for case hierarchy.
class ExportGuard {
  /// Check if case can be exported
  ///
  /// Group cases cannot be exported.
  /// Cases must have pages to export.
  static Future<bool> canExport(AppDatabase db, String caseId) async {
    final caseData = await db.getCase(caseId);

    if (caseData == null) {
      return false; // Case not found
    }

    if (caseData.isGroup) {
      return false; // ❌ Cannot export Group Cases
    }

    final pages = await db.getPagesByCase(caseId);
    if (pages.isEmpty) {
      return false; // ❌ No pages to export
    }

    return true; // ✅ Regular case with pages
  }

  /// Enforce export guard before export operation
  ///
  /// Throws exception if case cannot be exported.
  static Future<void> enforceExportGuard(
    AppDatabase db,
    String caseId,
  ) async {
    final caseData = await db.getCase(caseId);

    if (caseData == null) {
      throw Exception('Case not found');
    }

    if (caseData.isGroup) {
      throw Exception('Cannot export: case is a group');
    }

    final pages = await db.getPagesByCase(caseId);
    if (pages.isEmpty) {
      throw Exception('Cannot export: case has no pages');
    }
  }
}
