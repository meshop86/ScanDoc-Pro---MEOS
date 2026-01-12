import '../../data/database/database.dart';

/// Phase 21.3: Case Validation
///
/// Validates case creation and updates to enforce hierarchy constraints.
class CaseValidation {
  /// Validate case creation
  ///
  /// Returns error message if invalid, null if valid.
  static String? validateCreate(CasesCompanion companion) {
    final isGroup = companion.isGroup.value;
    final parentCaseId = companion.parentCaseId.value;

    // Rule 1: Group cases must be root-level (no nesting)
    if (isGroup && parentCaseId != null) {
      return '❌ Group cases cannot have a parent (no nesting)';
    }

    // Rule 2: Child cases must be regular (not groups)
    if (parentCaseId != null && isGroup) {
      return '❌ Child cases cannot be groups';
    }

    return null; // Valid
  }

  /// Validate case update
  ///
  /// Returns error message if invalid, null if valid.
  static Future<String?> validateUpdate(
    AppDatabase db,
    Case existingCase,
    CasesCompanion updates,
  ) async {
    // Prevent changing isGroup if case has pages
    if (updates.isGroup.present &&
        updates.isGroup.value != existingCase.isGroup) {
      final pages = await db.getPagesByCase(existingCase.id);
      if (pages.isNotEmpty) {
        return '❌ Cannot change case type: case has scanned pages';
      }
    }

    // Prevent setting parent if case is a group
    if (existingCase.isGroup && updates.parentCaseId.present) {
      return '❌ Group cases cannot be moved under another case';
    }

    // If setting parent, ensure it's a valid group
    if (updates.parentCaseId.present && updates.parentCaseId.value != null) {
      final parent = await db.getCase(updates.parentCaseId.value!);
      if (parent == null || !parent.isGroup) {
        return '❌ Parent must be a valid group case';
      }
    }

    return null; // Valid
  }
}
