import '../../data/database/database.dart';

/// Phase 21.3: Scan Guard
///
/// Enforces scan operation constraints for case hierarchy.
class ScanGuard {
  /// Check if case can be scanned
  ///
  /// Group cases cannot be scanned.
  static Future<bool> canScan(AppDatabase db, String caseId) async {
    final caseData = await db.getCase(caseId);

    if (caseData == null) {
      return false; // Case not found
    }

    if (caseData.isGroup) {
      return false; // ❌ Cannot scan into Group Cases
    }

    return true; // ✅ Regular case, can scan
  }

  /// Enforce scan guard before VisionKit
  ///
  /// Throws exception if case cannot be scanned.
  static Future<void> enforceScanGuard(
    AppDatabase db,
    String caseId,
  ) async {
    if (!await canScan(db, caseId)) {
      throw Exception('Cannot scan: case is a group');
    }
  }
}
