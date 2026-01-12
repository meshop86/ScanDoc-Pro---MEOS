import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models.dart' show CaseStatus;
import '../../utils/vietnamese_normalization.dart';

part 'database.g.dart';

// ============================================================================
// NEW PHASE 13 TABLES - Professional Document Scanner
// ============================================================================

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get username => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  TextColumn get signaturePath => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cases table - top-level document containers
class Cases extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()(); // active, completed, archived
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get ownerUserId => text()();

  // ============ PHASE 21: HIERARCHY SUPPORT ============
  /// Parent case ID for 1-level hierarchy
  /// - NULL: Top-level case (root)
  /// - Non-NULL: Child case (belongs to group)
  TextColumn get parentCaseId => text().nullable()();

  /// Whether this case is a group (folder of cases)
  /// - TRUE: Group case (can contain child cases, cannot scan/export)
  /// - FALSE: Regular case (cannot contain children, can scan/export)
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  // =====================================================

  @override
  Set<Column> get primaryKey => {id};
}

/// Folders table - optional organization within cases
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get caseId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pages table - scanned document pages
class Pages extends Table {
  TextColumn get id => text()();
  TextColumn get caseId => text()();
  TextColumn get folderId => text().nullable()(); // Optional folder
  TextColumn get name => text()();
  TextColumn get imagePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get pageNumber => integer().nullable()();
  TextColumn get status => text()(); // captured, processing, ready
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Exports table - exported files (PDF/ZIP) - Phase 20
class Exports extends Table {
  TextColumn get id => text()();
  TextColumn get filePath => text()(); // Full path to exported file
  TextColumn get fileName => text()(); // Display name (e.g., "Case 001.pdf")
  TextColumn get fileType => text()(); // "PDF" or "ZIP"
  TextColumn get caseId => text()(); // Reference to source case
  IntColumn get fileSize => integer().nullable()(); // Size in bytes
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// LEGACY TABLES - Kept for migration compatibility
// ============================================================================

@Deprecated('Legacy table. Use Cases instead.')
class Taps extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get ownerUserId => text()();
  TextColumn get signatureMetaJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@Deprecated('Legacy table. Use Folders instead.')
class Bos extends Table {
  TextColumn get id => text()();
  TextColumn get tapId => text()();
  TextColumn get licensePlate => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@Deprecated('Legacy table. Use Pages instead.')
class GiayTos extends Table {
  TextColumn get id => text()();
  TextColumn get boId => text()();
  TextColumn get name => text()();
  BoolColumn get requiredDoc => boolean().withDefault(const Constant(false))();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users, Cases, Folders, Pages, Exports, Taps, Bos, GiayTos])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  // Phase 23.1: Constructor for testing with in-memory database
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 4; // Phase 21: Case Hierarchy

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final filePath = p.join(dbFolder.path, 'scandoc_pro.db'); // Renamed database
      return SqfliteQueryExecutor(path: filePath);
    });
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from == 1) {
            // Phase 13 migration: Create new tables
            await m.createTable(cases);
            await m.createTable(folders);
            await m.createTable(pages);
            // Legacy tables (Taps, Bos, GiayTos) remain for data migration
          }
          if (from <= 2 && to >= 3) {
            // Phase 20 migration: Add Exports table
            await m.createTable(exports);
          }
          if (from <= 3 && to >= 4) {
            // Phase 21 migration: Add hierarchy support to Cases table
            await m.addColumn(cases, cases.parentCaseId);
            await m.addColumn(cases, cases.isGroup);
            print('✅ Phase 21 migration: Added parentCaseId + isGroup to Cases');
          }
        },
      );

  // ========================================================================
  // NEW API - Phase 13
  // ========================================================================

  // Cases
  Future<List<Case>> getAllCases() => (select(cases)..orderBy([(c) => OrderingTerm.desc(c.createdAt)])).get();
  Future<Case?> getCase(String id) => (select(cases)..where((c) => c.id.equals(id))).getSingleOrNull();
  Future<int> createCase(CasesCompanion caseData) => into(cases).insert(caseData);
  Future<bool> updateCase(CasesCompanion caseData) => update(cases).replace(caseData);
  Future<int> deleteCase(String id) => (delete(cases)..where((c) => c.id.equals(id))).go();

  // Folders
  Future<List<Folder>> getFoldersByCase(String caseId) =>
      (select(folders)..where((f) => f.caseId.equals(caseId))..orderBy([(f) => OrderingTerm.asc(f.name)])).get();
  Future<Folder?> getFolder(String id) => (select(folders)..where((f) => f.id.equals(id))).getSingleOrNull();
  Future<int> createFolder(FoldersCompanion folder) => into(folders).insert(folder);
  Future<bool> updateFolder(FoldersCompanion folder) => update(folders).replace(folder);
  Future<int> deleteFolder(String id) => (delete(folders)..where((f) => f.id.equals(id))).go();

  // Pages
  Future<List<Page>> getPagesByCase(String caseId) =>
      (select(pages)..where((p) => p.caseId.equals(caseId))..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).get();
  Future<List<Page>> getPagesByFolder(String folderId) =>
      (select(pages)..where((p) => p.folderId.equals(folderId))..orderBy([(p) => OrderingTerm.asc(p.pageNumber)])).get();
  Future<List<Page>> getUnfiledPages(String caseId) => (select(pages)
        ..where((p) => p.caseId.equals(caseId) & p.folderId.isNull())
        ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
      .get();
  Future<Page?> getPage(String id) => (select(pages)..where((p) => p.id.equals(id))).getSingleOrNull();
  Future<int> createPage(PagesCompanion page) => into(pages).insert(page);
  Future<bool> updatePage(PagesCompanion page) => update(pages).replace(page);
  Future<int> deletePage(String id) => (delete(pages)..where((p) => p.id.equals(id))).go();

  // Exports (Phase 20)
  Future<List<Export>> getAllExports() => (select(exports)..orderBy([(e) => OrderingTerm.desc(e.createdAt)])).get();
  Future<List<Export>> getExportsByCase(String caseId) =>
      (select(exports)..where((e) => e.caseId.equals(caseId))..orderBy([(e) => OrderingTerm.desc(e.createdAt)])).get();
  Future<Export?> getExport(String id) => (select(exports)..where((e) => e.id.equals(id))).getSingleOrNull();
  Future<int> createExport(ExportsCompanion export) => into(exports).insert(export);
  Future<int> deleteExport(String id) => (delete(exports)..where((e) => e.id.equals(id))).go();

  // ========================================================================
  // PHASE 21: HIERARCHY API
  // ========================================================================

  /// Get all top-level cases (no parent)
  Future<List<Case>> getTopLevelCases() =>
      (select(cases)
            ..where((c) => c.parentCaseId.isNull())
            ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
          .get();

  /// Get all group cases (isGroup = TRUE)
  Future<List<Case>> getGroupCases() =>
      (select(cases)
            ..where((c) => c.isGroup.equals(true))
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .get();

  /// Get all child cases under a parent group
  Future<List<Case>> getChildCases(String parentCaseId) =>
      (select(cases)
            ..where((c) => c.parentCaseId.equals(parentCaseId))
            ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
          .get();

  /// Get parent case of a child case
  Future<Case?> getParentCase(String childCaseId) async {
    final child = await getCase(childCaseId);
    if (child == null || child.parentCaseId == null) {
      return null;
    }
    return await getCase(child.parentCaseId!);
  }

  /// Check if case is a group
  Future<bool> isGroupCase(String caseId) async {
    final caseData = await getCase(caseId);
    return caseData?.isGroup ?? false;
  }

  /// Check if case can be scanned (not a group)
  Future<bool> canScanCase(String caseId) async {
    return !(await isGroupCase(caseId));
  }

  /// Check if case can be exported (not a group, has pages)
  Future<bool> canExportCase(String caseId) async {
    if (await isGroupCase(caseId)) return false;
    final pages = await getPagesByCase(caseId);
    return pages.isNotEmpty;
  }

  /// Get case hierarchy path (for breadcrumbs)
  /// Returns: [Group Case, Child Case] or [Root Case]
  Future<List<Case>> getCaseHierarchyPath(String caseId) async {
    final path = <Case>[];
    Case? current = await getCase(caseId);

    while (current != null) {
      path.insert(0, current); // Prepend to build top-down path

      if (current.parentCaseId == null) break; // Reached root
      current = await getCase(current.parentCaseId!);
    }

    return path;
  }

  /// Count child cases under group
  Future<int> getChildCaseCount(String parentCaseId) async {
    final children = await getChildCases(parentCaseId);
    return children.length;
  }

  /// Move case to different parent (or root)
  Future<void> moveCaseToParent(String caseId, String? newParentId) async {
    final caseData = await getCase(caseId);
    if (caseData == null) return;

    // Validation: Cannot move group under another case
    if (caseData.isGroup && newParentId != null) {
      throw Exception('Cannot move group case under another case');
    }

    // Validation: Parent must be a group case
    if (newParentId != null) {
      final parent = await getCase(newParentId);
      if (parent == null || !parent.isGroup) {
        throw Exception('Parent must be a group case');
      }
    }

    // Phase 21.FIX v5: Direct update with explicit values
    await (update(cases)..where((c) => c.id.equals(caseId)))
        .write(CasesCompanion(parentCaseId: Value(newParentId)));
    
    print('📝 DB move: $caseId → parent: $newParentId');
  }

  // ========================================================================
  // PHASE 22: SEARCH & FILTER API
  // ========================================================================

  /// Search and filter cases by name, status, and parent
  ///
  /// Phase 22.1: Non-OCR search - queries database directly for optimal performance
  /// Phase 24.2: Vietnamese normalization - supports diacritic-insensitive search
  ///
  /// Parameters:
  /// - [query]: Search term to match against case name (case-insensitive, partial match)
  ///   * null or empty → ignored (no name filtering)
  ///   * 'invoice' → matches 'Invoice 2024', 'invoice-jan', 'Tax Invoice'
  ///   * Phase 24.2: 'hoa don' → matches 'Hoá đơn', 'Hóa đơn', 'hoa don'
  ///   * Phase 24.2: 'hoá đơn' → matches 'Hoa don', 'hoá đơn', 'HOA DON'
  ///
  /// - [status]: Filter by case status (optional)
  ///   * null → all statuses
  ///   * CaseStatus.active → only active cases
  ///   * CaseStatus.completed → only completed cases
  ///   * CaseStatus.archived → only archived cases
  ///
  /// - [parentCaseId]: Filter by parent case (optional)
  ///   * null → all cases (top-level + children)
  ///   * 'TOP_LEVEL' → only top-level cases (parentCaseId IS NULL)
  ///   * other value → only children of specified parent
  ///
  /// Returns: List of regular cases (isGroup = FALSE) ordered by createdAt DESC
  ///
  /// Example usage:
  /// ```dart
  /// // Search all active cases containing "invoice"
  /// final cases = await db.searchCases('invoice', status: CaseStatus.active);
  ///
  /// // Phase 24.2: Vietnamese search (with or without diacritics)
  /// final vnCases = await db.searchCases('hoa don');  // matches "Hoá đơn"
  ///
  /// // Get all top-level completed cases
  /// final topCases = await db.searchCases(null,
  ///   status: CaseStatus.completed,
  ///   parentCaseId: 'TOP_LEVEL',
  /// );
  ///
  /// // Search in specific group
  /// final groupCases = await db.searchCases('contract',
  ///   parentCaseId: 'group-uuid-123',
  /// );
  /// ```
  ///
  /// Performance: 
  /// - Phase 22.1: < 100ms for 1000+ cases (SQL LIKE)
  /// - Phase 24.2: ~50ms for 1000 cases (Dart filtering with normalization)
  Future<List<Case>> searchCases(
    String? query, {
    CaseStatus? status,
    String? parentCaseId,
  }) async {
    // Start with base query: only regular cases (not groups)
    var stmt = select(cases)..where((c) => c.isGroup.equals(false));

    // Filter by status (SQL - for performance)
    if (status != null) {
      stmt = stmt..where((c) => c.status.equals(status.name));
    }

    // Filter by parent (SQL - for performance)
    if (parentCaseId == 'TOP_LEVEL') {
      // Special marker: only top-level cases
      stmt = stmt..where((c) => c.parentCaseId.isNull());
    } else if (parentCaseId != null) {
      // Specific parent: only children of this group
      stmt = stmt..where((c) => c.parentCaseId.equals(parentCaseId));
    }
    // else: null = all cases (no parent filter)

    // Order by most recent first
    stmt = stmt..orderBy([(c) => OrderingTerm.desc(c.createdAt)]);

    // Execute SQL query (fetch all cases matching non-name filters)
    final allCases = await stmt.get();

    // Filter by name (Dart - with Vietnamese normalization)
    // Phase 24.2: Moved from SQL LIKE to Dart filtering for diacritic-insensitive search
    if (query != null && query.trim().isNotEmpty) {
      final normalizedQuery = removeDiacritics(query.trim().toLowerCase());
      
      return allCases.where((c) {
        final normalizedName = removeDiacritics(c.name.toLowerCase());
        return normalizedName.contains(normalizedQuery);
      }).toList();
    }

    return allCases;
  }

  // ========================================================================
  // LEGACY API - Kept for backward compatibility
  // ========================================================================

  // Users
  Future<User> getUser(String id) => (select(users)..where((u) => u.id.equals(id))).getSingle();
  Future<List<User>> getAllUsers() => select(users).get();
  Future<int> createUser(UsersCompanion user) => into(users).insert(user);
  Future<bool> updateUser(UsersCompanion user) => update(users).replace(user);
  Future<int> deleteUser(String id) => (delete(users)..where((u) => u.id.equals(id))).go();

  // Taps (Legacy)
  @Deprecated('Use getAllCases instead')
  Future<List<Tap>> getAllTaps() => (select(taps)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  @Deprecated('Use getCase instead')
  Future<Tap?> getTap(String id) => (select(taps)..where((t) => t.id.equals(id))).getSingleOrNull();
  @Deprecated('Use createCase instead')
  Future<int> createTap(TapsCompanion tap) => into(taps).insert(tap);
  @Deprecated('Use updateCase instead')
  Future<bool> updateTap(TapsCompanion tap) => update(taps).replace(tap);
  @Deprecated('Use deleteCase instead')
  Future<int> deleteTap(String id) => (delete(taps)..where((t) => t.id.equals(id))).go();

  // Bos (Legacy)
  @Deprecated('Use getFoldersByCase instead')
  Future<List<Bo>> getBosByTap(String tapId) =>
      (select(bos)..where((b) => b.tapId.equals(tapId))..orderBy([(b) => OrderingTerm.desc(b.createdAt)])).get();
  @Deprecated('Use getFolder instead')
  Future<Bo?> getBo(String id) => (select(bos)..where((b) => b.id.equals(id))).getSingleOrNull();
  @Deprecated('Use createFolder instead')
  Future<int> createBo(BosCompanion bo) => into(bos).insert(bo);
  @Deprecated('Use updateFolder instead')
  Future<bool> updateBo(BosCompanion bo) => update(bos).replace(bo);
  @Deprecated('Use deleteFolder instead')
  Future<int> deleteBo(String id) => (delete(bos)..where((b) => b.id.equals(id))).go();

  // GiayTos (Legacy)
  @Deprecated('Use getPagesByFolder instead')
  Future<List<GiayTo>> getGiayTosByBo(String boId) =>
      (select(giayTos)..where((g) => g.boId.equals(boId))..orderBy([(g) => OrderingTerm.asc(g.createdAt)])).get();
  @Deprecated('Use getPage instead')
  Future<GiayTo?> getGiayTo(String id) => (select(giayTos)..where((g) => g.id.equals(id))).getSingleOrNull();
  @Deprecated('Use createPage instead')
  Future<int> createGiayTo(GiayTosCompanion giayTo) => into(giayTos).insert(giayTo);
  @Deprecated('Use updatePage instead')
  Future<bool> updateGiayTo(GiayTosCompanion giayTo) => update(giayTos).replace(giayTo);
  @Deprecated('Use deletePage instead')
  Future<int> deleteGiayTo(String id) => (delete(giayTos)..where((g) => g.id.equals(id))).go();
}
