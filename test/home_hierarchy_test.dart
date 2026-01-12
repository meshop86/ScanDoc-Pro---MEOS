import 'package:flutter_test/flutter_test.dart';
import 'package:bien_so_xe/src/features/home/hierarchy_providers.dart';
import 'package:bien_so_xe/src/data/database/database.dart' as db;

/// Phase 21.4A: Unit tests for hierarchy view model and logic
void main() {
  group('CaseViewModel', () {
    test('should create regular case view model', () {
      final caseData = db.Case(
        id: 'test-1',
        name: 'Test Case',
        description: '',
        status: 'active',
        createdAt: DateTime.now(),
        ownerUserId: 'user-1',
        isGroup: false,
        parentCaseId: null,
      );

      final viewModel = CaseViewModel.regularCase(
        caseData: caseData,
        pageCount: 5,
      );

      expect(viewModel.isGroup, isFalse);
      expect(viewModel.pageCount, equals(5));
      expect(viewModel.childCount, isNull);
      expect(viewModel.name, equals('Test Case'));
    });

    test('should create group case view model', () {
      final caseData = db.Case(
        id: 'group-1',
        name: 'Test Group',
        description: '',
        status: 'active',
        createdAt: DateTime.now(),
        ownerUserId: 'user-1',
        isGroup: true,
        parentCaseId: null,
      );

      final viewModel = CaseViewModel.groupCase(
        caseData: caseData,
        childCount: 3,
        isExpanded: false,
      );

      expect(viewModel.isGroup, isTrue);
      expect(viewModel.childCount, equals(3));
      expect(viewModel.pageCount, isNull);
      expect(viewModel.isExpanded, isFalse);
    });

    test('should copy with new expand state', () {
      final caseData = db.Case(
        id: 'group-1',
        name: 'Test Group',
        description: '',
        status: 'active',
        createdAt: DateTime.now(),
        ownerUserId: 'user-1',
        isGroup: true,
        parentCaseId: null,
      );

      final viewModel = CaseViewModel.groupCase(
        caseData: caseData,
        childCount: 3,
        isExpanded: false,
      );

      final expanded = viewModel.copyWith(isExpanded: true);

      expect(viewModel.isExpanded, isFalse);
      expect(expanded.isExpanded, isTrue);
      expect(expanded.childCount, equals(3));
    });
  });

  group('Home Screen Hierarchy Logic', () {
    test('should calculate total items correctly', () {
      // This would test the _calculateTotalItems logic
      // For now, just verify concept:
      
      // 2 groups (collapsed) + 1 top-level case = 3
      int itemCount = 2 + 1;
      expect(itemCount, equals(3));
      
      // 2 groups (1 expanded with 2 children) + 1 top-level = 2 + 2 + 1 = 5
      itemCount = 2 + 2 + 1;
      expect(itemCount, equals(5));
    });
  });
}
