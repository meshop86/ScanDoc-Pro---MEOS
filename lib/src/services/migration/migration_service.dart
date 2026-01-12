import 'package:drift/drift.dart';
import '../../data/database/database.dart';
import '../../domain/models.dart';

/// Phase 13.1 Migration Service
/// Handles one-time migration from Phase 12 (Tap/Bo/GiayTo) to Phase 13 (Case/Folder/Page)
/// 
/// Migration flow:
/// - TapHoSo → Case
/// - BoHoSo → Folder (within Case)
/// - GiayTo → Page (within Folder)
/// - File paths remain unchanged (migration is logical only)
class MigrationService {
  final AppDatabase db;

  MigrationService(this.db);

  /// Run migration once on app startup
  /// Returns true if migration was executed, false if already done
  Future<bool> runMigrationIfNeeded() async {
    try {
      // Check if old data exists and new data is empty
      final oldTaps = await db.getAllTaps();
      final newCases = await db.getAllCases();

      // If new data already exists, skip migration
      if (newCases.isNotEmpty) {
        print('✓ Migration already completed (Cases found)');
        return false;
      }

      // If no old data, nothing to migrate
      if (oldTaps.isEmpty) {
        print('✓ No legacy data to migrate');
        return false;
      }

      print('⚡ Starting Phase 13 migration...');
      
      // Run migration in transaction
      await db.transaction(() async {
        await _migrateTapsToCases(oldTaps);
      });

      print('✓ Phase 13 migration completed successfully');
      return true;
    } catch (e) {
      print('✗ Migration failed: $e');
      rethrow;
    }
  }

  /// Migrate all Taps to Cases with nested Folders and Pages
  Future<void> _migrateTapsToCases(List<Tap> taps) async {
    for (final tap in taps) {
      // 1. Create Case from Tap
      final caseData = CasesCompanion(
        id: Value(tap.id),
        name: Value(tap.code),
        status: Value(tap.status == 'completed' ? 'completed' : 'active'),
        createdAt: Value(tap.createdAt),
        completedAt: Value(tap.completedAt),
        ownerUserId: Value(tap.ownerUserId),
      );
      await db.createCase(caseData);
      print('  ✓ Created Case: ${tap.code}');

      // 2. Migrate Bos to Folders and GiayTos to Pages
      final bos = await db.getBosByTap(tap.id);
      for (final bo in bos) {
        // Create Folder from Bo
        final folderData = FoldersCompanion(
          id: Value(bo.id),
          caseId: Value(tap.id),
          name: Value(bo.licensePlate), // License plate becomes folder name
          createdAt: Value(bo.createdAt),
          updatedAt: Value(bo.updatedAt),
        );
        await db.createFolder(folderData);
        print('    ✓ Created Folder: ${bo.licensePlate}');

        // Migrate GiayTos to Pages
        final giaytos = await db.getGiayTosByBo(bo.id);
        for (final giayto in giaytos) {
          // Skip documents without images (missing docs)
          if (giayto.imagePath == null) {
            print('      ⊘ Skipped missing document: ${giayto.name}');
            continue;
          }

          final pageData = PagesCompanion(
            id: Value(giayto.id),
            caseId: Value(tap.id),
            folderId: Value(bo.id),
            name: Value(giayto.name),
            imagePath: Value(giayto.imagePath!),
            status: const Value('ready'),
            createdAt: Value(giayto.createdAt),
            updatedAt: Value(giayto.updatedAt),
          );
          await db.createPage(pageData);
        }
        print('      ✓ Migrated ${giaytos.length} pages');
      }
    }
  }
}
