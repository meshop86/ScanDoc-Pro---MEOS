// Phase 23.1: Unit Tests - searchCases()
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:scandocpro/src/data/database/database.dart' as db;
import 'package:scandocpro/src/domain/models.dart';
import 'package:uuid/uuid.dart';

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase.forTesting();
  });

  tearDown(() async {
    await database.close();
  });

  group('searchCases() - Basic', () {
    test('returns all cases when no filters', () async {
      await createCase(database, 'Case 1', 'active');
      await createCase(database, 'Case 2', 'completed');
      
      final results = await database.searchCases(null);
      
      expect(results.length, 2);
    });

    test('filters by name LIKE query', () async {
      await createCase(database, 'Invoice 2024', 'active');
      await createCase(database, 'Tax Invoice', 'active');
      await createCase(database, 'Contract', 'active');

      final results = await database.searchCases('Invoice');

      expect(results.length, 2);
    });

    test('case-insensitive search', () async {
      await createCase(database, 'Invoice 2024', 'active');

      final results = await database.searchCases('invoice');

      expect(results.length, 1);
    });
  });

  group('searchCases() - Status', () {
    test('filters by active', () async {
      await createCase(database, 'Case 1', 'active');
      await createCase(database, 'Case 2', 'completed');

      final results = await database.searchCases(null, status: CaseStatus.active);

      expect(results.length, 1);
      expect(results[0].status, 'active');
    });
  });

  group('searchCases() - Parent', () {
    test('filters TOP_LEVEL', () async {
      final groupId = await createCase(database, 'Group', 'active', isGroup: true);
      await createCase(database, 'Top', 'active');
      await createCase(database, 'Child', 'active', parentId: groupId);

      final results = await database.searchCases(null, parentCaseId: 'TOP_LEVEL');

      expect(results.length, 1);
      expect(results[0].name, 'Top');
    });
  });

  group('searchCases() - Exclusions', () {
    test('excludes groups', () async {
      await createCase(database, 'Group', 'active', isGroup: true);
      await createCase(database, 'Case', 'active');

      final results = await database.searchCases(null);

      expect(results.length, 1);
      expect(results[0].isGroup, false);
    });
  });
}

Future<String> createCase(
  db.AppDatabase database,
  String name,
  String status, {
  bool isGroup = false,
  String? parentId,
}) async {
  final id = const Uuid().v4();
  await database.into(database.cases).insert(
        db.CasesCompanion.insert(
          id: id,
          ownerUserId: 'test-user-id',
          name: name,
          status: status,
          createdAt: DateTime.now(),
          isGroup: Value(isGroup),
          parentCaseId: Value(parentId),
        ),
      );
  return id;
}
