import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scandocpro/src/features/home/search_providers.dart';
import 'package:scandocpro/src/features/home/case_providers.dart' show databaseProvider;
import 'package:scandocpro/src/domain/models.dart' show CaseStatus;
import 'package:scandocpro/src/data/database/database.dart' as db;
import 'fake_database.dart';

/// Phase 23.2: Provider tests for Search & Filter (Phase 22)

void main() {
  group('searchFilterProvider', () {
    test('initial state is empty SearchFilter', () {
      // GIVEN: Fresh ProviderContainer
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // WHEN: Read initial state
      final filter = container.read(searchFilterProvider);
      
      // THEN: State is SearchFilter.empty
      expect(filter.isEmpty, true);
      expect(filter.query, null);
      expect(filter.status, null);
      expect(filter.parentCaseId, null);
    });
    
    test('updates query → state changes', () {
      // GIVEN: Container with empty filter
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // WHEN: Update query
      container.read(searchFilterProvider.notifier).state = const SearchFilter(
        query: 'invoice',
      );
      
      // THEN: State reflects new query
      final filter = container.read(searchFilterProvider);
      expect(filter.query, 'invoice');
      expect(filter.isEmpty, false);
    });
    
    test('updates status → state changes', () {
      // GIVEN: Container with empty filter
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // WHEN: Update status
      container.read(searchFilterProvider.notifier).state = const SearchFilter(
        status: CaseStatus.active,
      );
      
      // THEN: State reflects new status
      final filter = container.read(searchFilterProvider);
      expect(filter.status, CaseStatus.active);
      expect(filter.isEmpty, false);
    });
    
    test('reset → state becomes empty', () {
      // GIVEN: Container with active filter
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      container.read(searchFilterProvider.notifier).state = const SearchFilter(
        query: 'test',
        status: CaseStatus.completed,
      );
      
      // WHEN: Reset to empty filter
      container.read(searchFilterProvider.notifier).state = const SearchFilter();
      
      // THEN: State is empty
      final filter = container.read(searchFilterProvider);
      expect(filter.isEmpty, true);
      expect(filter.query, null);
      expect(filter.status, null);
    });
  });
  
  group('filteredCasesProvider', () {
    test('empty filter → calls getTopLevelCases()', () async {
      // GIVEN: FakeDatabase with top-level data
      final fakeDb = FakeAppDatabase();
      final testCases = [
        _createCase('Case 1', 'active'),
        _createCase('Case 2', 'completed'),
      ];
      fakeDb.setTopLevelCases(testCases);
      
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read provider with empty filter (default)
      final cases = await container.read(filteredCasesProvider.future);
      
      // THEN: getTopLevelCases() called, searchCases() NOT called
      expect(fakeDb.getTopLevelCasesCalls, 1);
      expect(fakeDb.searchCasesCalls, 0);
      expect(cases.length, 2);
    });
    
    test('active filter → calls searchCases()', () async {
      // GIVEN: FakeDatabase with search results
      final fakeDb = FakeAppDatabase();
      final searchResults = [
        _createCase('Invoice 1', 'active'),
      ];
      fakeDb.setSearchResults(searchResults);
      
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(query: 'invoice');
          }),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read provider with active filter
      final cases = await container.read(filteredCasesProvider.future);
      
      // THEN: searchCases() called with correct parameters
      expect(fakeDb.searchCasesCalls, 1);
      expect(fakeDb.lastSearchQuery, 'invoice');
      expect(fakeDb.getTopLevelCasesCalls, 0);
      expect(cases.length, 1);
    });
    
    test('filter change → provider recomputes', () async {
      // GIVEN: Container with FakeDatabase
      final fakeDb = FakeAppDatabase();
      fakeDb.setTopLevelCases([_createCase('Top', 'active')]);
      fakeDb.setSearchResults([_createCase('Search', 'active')]);
      
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: First read with empty filter
      var cases = await container.read(filteredCasesProvider.future);
      
      // THEN: getTopLevelCases() called
      expect(fakeDb.getTopLevelCasesCalls, 1);
      expect(cases.first.name, 'Top');
      
      // WHEN: Change filter to active
      fakeDb.resetTracking();
      container.read(searchFilterProvider.notifier).state = const SearchFilter(
        query: 'test',
      );
      
      // Force refresh by invalidating provider
      container.invalidate(filteredCasesProvider);
      
      // Read again (should recompute)
      cases = await container.read(filteredCasesProvider.future);
      
      // THEN: searchCases() called (recomputed)
      expect(fakeDb.searchCasesCalls, 1);
      expect(fakeDb.lastSearchQuery, 'test');
      expect(cases.first.name, 'Search');
    });
    
    test('passes status filter to searchCases()', () async {
      // GIVEN: FakeDatabase with filter
      final fakeDb = FakeAppDatabase();
      fakeDb.setSearchResults([_createCase('Active', 'active')]);
      
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(status: CaseStatus.active);
          }),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read provider
      await container.read(filteredCasesProvider.future);
      
      // THEN: searchCases() received status parameter
      expect(fakeDb.lastSearchStatus, CaseStatus.active);
    });
    
    test('passes parent filter to searchCases()', () async {
      // GIVEN: FakeDatabase with parent filter
      final fakeDb = FakeAppDatabase();
      fakeDb.setSearchResults([_createCase('Child', 'active')]);
      
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(parentCaseId: 'TOP_LEVEL');
          }),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read provider
      await container.read(filteredCasesProvider.future);
      
      // THEN: searchCases() received parent parameter
      expect(fakeDb.lastSearchParent, 'TOP_LEVEL');
    });
  });
  
  group('isFilterActiveProvider', () {
    test('empty filter → false', () {
      // GIVEN: Container with empty filter
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // WHEN: Read isFilterActiveProvider
      final isActive = container.read(isFilterActiveProvider);
      
      // THEN: Returns false
      expect(isActive, false);
    });
    
    test('query present → true', () {
      // GIVEN: Container with query
      final container = ProviderContainer(
        overrides: [
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(query: 'test');
          }),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read isFilterActiveProvider
      final isActive = container.read(isFilterActiveProvider);
      
      // THEN: Returns true
      expect(isActive, true);
    });
    
    test('status present → true', () {
      // GIVEN: Container with status
      final container = ProviderContainer(
        overrides: [
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(status: CaseStatus.active);
          }),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read isFilterActiveProvider
      final isActive = container.read(isFilterActiveProvider);
      
      // THEN: Returns true
      expect(isActive, true);
    });
  });
  
  group('activeFilterCountProvider', () {
    test('empty filter → count 0', () {
      // GIVEN: Container with empty filter
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // WHEN: Read activeFilterCountProvider
      final count = container.read(activeFilterCountProvider);
      
      // THEN: Count is 0
      expect(count, 0);
    });
    
    test('query only → count 1', () {
      // GIVEN: Container with query
      final container = ProviderContainer(
        overrides: [
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(query: 'test');
          }),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read activeFilterCountProvider
      final count = container.read(activeFilterCountProvider);
      
      // THEN: Count is 1
      expect(count, 1);
    });
    
    test('status + parentCaseId → count 2', () {
      // GIVEN: Container with 2 filters
      final container = ProviderContainer(
        overrides: [
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(
              status: CaseStatus.active,
              parentCaseId: 'TOP_LEVEL',
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read activeFilterCountProvider
      final count = container.read(activeFilterCountProvider);
      
      // THEN: Count is 2
      expect(count, 2);
    });
    
    test('all filters → count 3', () {
      // GIVEN: Container with all 3 filters
      final container = ProviderContainer(
        overrides: [
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(
              query: 'invoice',
              status: CaseStatus.completed,
              parentCaseId: 'group-123',
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read activeFilterCountProvider
      final count = container.read(activeFilterCountProvider);
      
      // THEN: Count is 3
      expect(count, 3);
    });
    
    test('empty query string → count 0 (whitespace ignored)', () {
      // GIVEN: Container with empty/whitespace query
      final container = ProviderContainer(
        overrides: [
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(query: '   ');
          }),
        ],
      );
      addTearDown(container.dispose);
      
      // WHEN: Read activeFilterCountProvider
      final count = container.read(activeFilterCountProvider);
      
      // THEN: Count is 0 (whitespace query ignored)
      expect(count, 0);
    });
  });
}

/// Helper: Create test case
db.Case _createCase(String name, String status) {
  return db.Case(
    id: 'test-${name.toLowerCase()}',
    ownerUserId: 'test-user',
    name: name,
    status: status,
    createdAt: DateTime.now(),
    isGroup: false,
    parentCaseId: null,
  );
}
