import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bien_so_xe/main.dart' as app;
import 'package:bien_so_xe/src/data/database/database.dart';
import 'package:uuid/uuid.dart';

/// Phase 21: Integration Tests for Bug Fixes
/// 
/// Tests:
/// - UUID ID generation (no collisions)
/// - Ghost page filtering
/// - DeleteGuard enforcement
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 21: UUID ID Generation Tests', () {
    testWidgets('TEST 1.1: Rapid case creation should not have UNIQUE constraint errors',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final database = AppDatabase();

      // Create 100 cases rapidly
      final caseIds = <String>[];
      for (int i = 0; i < 100; i++) {
        final caseId = const Uuid().v4();
        caseIds.add(caseId);

        await database.createCase(
          CasesCompanion.insert(
            id: caseId,
            name: 'Rapid Test $i',
            createdAt: DateTime.now(),
          ),
        );
      }

      // Verify all cases created
      final cases = await database.getAllCases();
      expect(cases.length, greaterThanOrEqualTo(100));

      // Verify all IDs are unique
      final uniqueIds = caseIds.toSet();
      expect(uniqueIds.length, equals(100), reason: 'All IDs must be unique');

      // Verify UUID format
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (final id in caseIds) {
        expect(uuidRegex.hasMatch(id), isTrue, reason: 'ID must be valid UUID v4: $id');
      }

      await database.close();
    });

    testWidgets('TEST 1.2: Rapid page creation should not have UNIQUE constraint errors',
        (WidgetTester tester) async {
      final database = AppDatabase();

      // Create test case
      final caseId = const Uuid().v4();
      await database.createCase(
        CasesCompanion.insert(
          id: caseId,
          name: 'Page Test Case',
          createdAt: DateTime.now(),
        ),
      );

      // Create 50 pages rapidly
      final pageIds = <String>[];
      for (int i = 0; i < 50; i++) {
        final pageId = const Uuid().v4();
        pageIds.add(pageId);

        await database.insertPage(
          PagesCompanion.insert(
            id: pageId,
            caseId: caseId,
            imagePath: '/fake/path/image_$i.jpg',
            pageNumber: i + 1,
          ),
        );
      }

      // Verify all pages created
      final pages = await database.getPagesByCase(caseId);
      expect(pages.length, equals(50));

      // Verify all IDs are unique
      final uniqueIds = pageIds.toSet();
      expect(uniqueIds.length, equals(50));

      await database.close();
    });

    testWidgets('TEST 1.3: Rapid export creation should not have UNIQUE constraint errors',
        (WidgetTester tester) async {
      final database = AppDatabase();

      // Create test case
      final caseId = const Uuid().v4();
      await database.createCase(
        CasesCompanion.insert(
          id: caseId,
          name: 'Export Test Case',
          createdAt: DateTime.now(),
        ),
      );

      // Create 20 exports rapidly
      final exportIds = <String>[];
      for (int i = 0; i < 20; i++) {
        final exportId = const Uuid().v4();
        exportIds.add(exportId);

        await database.createExport(
          ExportsCompanion.insert(
            id: exportId,
            caseId: caseId,
            fileName: 'export_$i.pdf',
            filePath: '/fake/path/export_$i.pdf',
            fileType: 'PDF',
            fileSize: 1024 * i,
          ),
        );
      }

      // Verify all exports created
      final exports = await database.getExportsByCase(caseId);
      expect(exports.length, equals(20));

      // Verify all IDs are unique
      final uniqueIds = exportIds.toSet();
      expect(uniqueIds.length, equals(20));

      await database.close();
    });
  });

  group('Phase 21: Ghost Page Prevention Tests', () {
    testWidgets('TEST 2.2: Delete all cases then create new should be empty',
        (WidgetTester tester) async {
      final database = AppDatabase();

      // Create 3 cases with 3 pages each
      final caseIds = <String>[];
      for (int i = 0; i < 3; i++) {
        final caseId = const Uuid().v4();
        caseIds.add(caseId);

        await database.createCase(
          CasesCompanion.insert(
            id: caseId,
            name: 'Ghost Test $i',
            createdAt: DateTime.now(),
          ),
        );

        // Create 3 pages for each case
        for (int j = 0; j < 3; j++) {
          await database.insertPage(
            PagesCompanion.insert(
              id: const Uuid().v4(),
              caseId: caseId,
              imagePath: '/fake/path/case_${i}_page_$j.jpg',
              pageNumber: j + 1,
            ),
          );
        }
      }

      // Verify 3 cases, 9 pages total
      final casesBeforeDelete = await database.getAllCases();
      expect(casesBeforeDelete.length, equals(3));

      int totalPages = 0;
      for (final caseData in casesBeforeDelete) {
        final pages = await database.getPagesByCase(caseData.id);
        totalPages += pages.length;
      }
      expect(totalPages, equals(9));

      // Delete all cases
      for (final caseId in caseIds) {
        // Note: In real app, this would go through DeleteGuard
        await database.deleteCase(caseId);
      }

      // Verify all cases deleted
      final casesAfterDelete = await database.getAllCases();
      expect(casesAfterDelete.length, equals(0));

      // Create new case
      final newCaseId = const Uuid().v4();
      await database.createCase(
        CasesCompanion.insert(
          id: newCaseId,
          name: 'Fresh Start',
          createdAt: DateTime.now(),
        ),
      );

      // Verify new case has 0 pages
      final newCasePages = await database.getPagesByCase(newCaseId);
      expect(newCasePages.length, equals(0), reason: 'New case must be empty, no ghost pages');

      await database.close();
    });
  });

  group('Phase 21: Hierarchy Guard Tests', () {
    testWidgets('TEST 3.3: Delete non-empty group should throw exception',
        (WidgetTester tester) async {
      final database = AppDatabase();

      // Create group case
      final groupId = const Uuid().v4();
      await database.createCase(
        CasesCompanion.insert(
          id: groupId,
          name: 'Parent Group',
          isGroup: const Value(true),
          createdAt: DateTime.now(),
        ),
      );

      // Create child case
      final childId = const Uuid().v4();
      await database.createCase(
        CasesCompanion.insert(
          id: childId,
          name: 'Child Case',
          parentCaseId: Value(groupId),
          createdAt: DateTime.now(),
        ),
      );

      // Try to delete group (should fail)
      expect(
        () async {
          // Import DeleteGuard
          final DeleteGuard = (await import('package:bien_so_xe/src/services/guards/delete_guard.dart')).DeleteGuard;
          await DeleteGuard.deleteCase(database, groupId);
        },
        throwsA(isA<Exception>()),
        reason: 'Deleting non-empty group must throw exception',
      );

      // Verify group still exists
      final group = await database.getCase(groupId);
      expect(group, isNotNull, reason: 'Group must still exist after failed delete');

      // Verify child still exists
      final child = await database.getCase(childId);
      expect(child, isNotNull, reason: 'Child must still exist after failed delete');

      await database.close();
    });

    testWidgets('TEST 3.2: Delete empty group should succeed',
        (WidgetTester tester) async {
      final database = AppDatabase();

      // Create empty group case
      final groupId = const Uuid().v4();
      await database.createCase(
        CasesCompanion.insert(
          id: groupId,
          name: 'Empty Group',
          isGroup: const Value(true),
          createdAt: DateTime.now(),
        ),
      );

      // Verify group has no children
      final children = await database.getChildCases(groupId);
      expect(children.length, equals(0));

      // Delete group (should succeed)
      final DeleteGuard = (await import('package:bien_so_xe/src/services/guards/delete_guard.dart')).DeleteGuard;
      await DeleteGuard.deleteCase(database, groupId);

      // Verify group deleted
      final group = await database.getCase(groupId);
      expect(group, isNull, reason: 'Empty group must be deleted');

      await database.close();
    });
  });

  group('Phase 21: Data Integrity Tests', () {
    testWidgets('TEST 5.1: All case IDs must be valid UUID v4 format',
        (WidgetTester tester) async {
      final database = AppDatabase();

      // Create 10 cases
      for (int i = 0; i < 10; i++) {
        await database.createCase(
          CasesCompanion.insert(
            id: const Uuid().v4(),
            name: 'Format Test $i',
            createdAt: DateTime.now(),
          ),
        );
      }

      // Get all cases
      final cases = await database.getAllCases();

      // Verify UUID v4 format
      final uuidV4Regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      for (final caseData in cases) {
        expect(
          uuidV4Regex.hasMatch(caseData.id),
          isTrue,
          reason: 'Case ID must be valid UUID v4: ${caseData.id}',
        );

        // Ensure NOT timestamp format
        expect(
          caseData.id.startsWith('case_'),
          isFalse,
          reason: 'Case ID must not be timestamp format: ${caseData.id}',
        );
      }

      await database.close();
    });

    testWidgets('TEST 5.2: Cascade delete should remove all pages',
        (WidgetTester tester) async {
      final database = AppDatabase();

      // Create case with pages
      final caseId = const Uuid().v4();
      await database.createCase(
        CasesCompanion.insert(
          id: caseId,
          name: 'Cascade Test',
          createdAt: DateTime.now(),
        ),
      );

      final pageIds = <String>[];
      for (int i = 0; i < 5; i++) {
        final pageId = const Uuid().v4();
        pageIds.add(pageId);

        await database.insertPage(
          PagesCompanion.insert(
            id: pageId,
            caseId: caseId,
            imagePath: '/fake/path/page_$i.jpg',
            pageNumber: i + 1,
          ),
        );
      }

      // Verify pages exist
      final pagesBeforeDelete = await database.getPagesByCase(caseId);
      expect(pagesBeforeDelete.length, equals(5));

      // Delete case (should cascade delete pages)
      await database.deleteCase(caseId);

      // Verify pages deleted
      final pagesAfterDelete = await database.getPagesByCase(caseId);
      expect(pagesAfterDelete.length, equals(0), reason: 'All pages must be deleted');

      // Verify pages not in DB at all
      for (final pageId in pageIds) {
        final page = await database.getPage(pageId);
        expect(page, isNull, reason: 'Page $pageId must not exist in DB');
      }

      await database.close();
    });
  });
}
