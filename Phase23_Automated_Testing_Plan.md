# Phase 23: Automated Testing & Stability - Implementation Plan

**Phase**: 23 (Automated Testing)  
**Date**: 2025-01-12  
**Status**: 🚧 **IN PROGRESS**

---

## Executive Summary

Phase 23 adds automated test coverage to protect core features (Phase 21 Hierarchy + Phase 22 Search & Filter) from regression. Focus on critical business logic rather than UI animations.

**Goal**: >70% coverage for core features  
**Strategy**: 3 sub-phases (Unit → Provider → Widget)  
**Duration**: ~6-8 hours estimated  

---

## Objectives

### Primary Goals

1. **Prevent Regression**: Catch bugs before production
2. **Document Behavior**: Tests as living documentation
3. **Enable Refactoring**: Confidence to improve code later

### Non-Goals

- ❌ NOT adding new features
- ❌ NOT refactoring production code (unless necessary for testing)
- ❌ NOT 100% coverage (focus on critical paths)
- ❌ NOT testing external libraries (Drift, Riverpod internals)

---

## Phase Structure

### Phase 23.1: Unit Tests (Database & Logic)

**Target Functions:**
1. `searchCases()` - Search query with filters (Phase 22.1)
2. Move Case logic - Hierarchy manipulation (Phase 21)
3. `DeleteGuard` - Safety checks (Phase 14K)
4. Quick Scan case binding - Scan module integration

**Test Framework:**
- `package:test` (Dart unit testing)
- `package:drift/drift.dart` (In-memory database for tests)
- `package:mockito` or manual mocks

**Coverage Target:** >80% for tested functions

**Deliverable:** `Phase23_1_Unit_Tests_Report.md`

---

### Phase 23.2: Provider Tests (State Management)

**Target Providers:**
1. `searchFilterProvider` - Filter state updates
2. `filteredCasesProvider` - Async query results
3. `isFilterActiveProvider` - Computed filter status
4. `activeFilterCountProvider` - Computed filter count

**Test Framework:**
- `package:flutter_riverpod` testing utilities
- `package:mockito` for database mocks
- `ProviderContainer` for isolated tests

**Coverage Target:** >75% for provider logic

**Deliverable:** `Phase23_2_Provider_Tests_Report.md`

---

### Phase 23.3: Widget Tests (UI Behavior)

**Target Components:**
1. **Search Bar Reset**:
   - X button clears text + resets filter
   - Keyboard delete resets to hierarchy
   - Debounce behavior (300ms delay)

2. **Filter Chips**:
   - Toggle status filters (Active/Completed/Archived)
   - Toggle parent filter (Top-level only)
   - Clear Filters button

3. **Empty States**:
   - "No cases yet" (no filters)
   - "No cases found" (filtering)
   - Mode switching (search vs hierarchy)

**Test Framework:**
- `package:flutter_test` (Widget testing)
- `testWidgets()` for UI interactions
- Mock providers with `ProviderScope`

**Coverage Target:** >60% for UI logic (skip animations)

**Deliverable:** `Phase23_3_Widget_Tests_Report.md`

---

## Test Principles

### GIVEN / WHEN / THEN Pattern

```dart
test('searchCases filters by status', () {
  // GIVEN: Database with 3 active, 2 completed cases
  await seedDatabase(db, active: 3, completed: 2);
  
  // WHEN: Search with status filter
  final results = await db.searchCases(null, status: CaseStatus.active);
  
  // THEN: Only active cases returned
  expect(results.length, 3);
  expect(results.every((c) => c.status == 'active'), isTrue);
});
```

### Test Independence

```dart
setUp(() {
  // Create fresh database before each test
  db = AppDatabase.forTesting();
});

tearDown(() async {
  // Clean up after each test
  await db.close();
});
```

### Mock vs Real

**Use Real:**
- Drift database (in-memory mode)
- Riverpod providers (with mock dependencies)

**Use Mocks:**
- External services (network, file system)
- Heavy dependencies (ML Kit, camera)

---

## Test File Structure

```
test/
├── unit/
│   ├── database/
│   │   ├── search_cases_test.dart         # Phase 23.1
│   │   └── move_case_test.dart            # Phase 23.1
│   ├── logic/
│   │   ├── delete_guard_test.dart         # Phase 23.1
│   │   └── quick_scan_binding_test.dart   # Phase 23.1
├── provider/
│   ├── search_filter_provider_test.dart   # Phase 23.2
│   └── filtered_cases_provider_test.dart  # Phase 23.2
├── widget/
│   ├── home_screen_search_test.dart       # Phase 23.3
│   └── home_screen_filters_test.dart      # Phase 23.3
└── helpers/
    ├── database_test_helper.dart          # Shared utilities
    └── provider_test_helper.dart          # Shared utilities
```

---

## Phase 23.1 Details (Unit Tests)

### Test 1: searchCases() Query Logic

**File**: `test/unit/database/search_cases_test.dart`

**Test Cases:**
```dart
group('searchCases()', () {
  test('returns all cases when no filters', () { ... });
  test('filters by name (LIKE query)', () { ... });
  test('filters by status', () { ... });
  test('filters by parentCaseId (top-level)', () { ... });
  test('combines multiple filters (name + status)', () { ... });
  test('is case-insensitive', () { ... });
  test('trims whitespace', () { ... });
  test('orders by createdAt DESC', () { ... });
  test('excludes groups (isGroup=false)', () { ... });
});
```

**Setup:**
```dart
late AppDatabase db;

setUp(() {
  db = AppDatabase.forTesting(); // In-memory database
});

tearDown(() async {
  await db.close();
});

Future<void> seedTestCases(AppDatabase db) async {
  await db.into(db.cases).insert(CasesCompanion.insert(
    name: 'Công ty TNHH ABC',
    status: 'active',
    createdAt: DateTime.now(),
    isGroup: const drift.Value(false),
  ));
  // ... more test data
}
```

### Test 2: Move Case Logic

**File**: `test/unit/database/move_case_test.dart`

**Test Cases:**
```dart
group('Move Case', () {
  test('moves case to different parent', () { ... });
  test('moves case to top-level (null parent)', () { ... });
  test('prevents circular reference (case → child → case)', () { ... });
  test('updates parentCaseId in database', () { ... });
});
```

### Test 3: DeleteGuard

**File**: `test/unit/logic/delete_guard_test.dart`

**Test Cases:**
```dart
group('DeleteGuard', () {
  test('allows delete when no children', () { ... });
  test('blocks delete when has children', () { ... });
  test('allows force delete with children', () { ... });
  test('returns correct child count', () { ... });
});
```

### Test 4: Quick Scan Binding

**File**: `test/unit/logic/quick_scan_binding_test.dart`

**Test Cases:**
```dart
group('Quick Scan Case Binding', () {
  test('creates case from scan result', () { ... });
  test('links scan images to case', () { ... });
  test('sets correct case name from scan', () { ... });
});
```

---

## Phase 23.2 Details (Provider Tests)

### Test 1: searchFilterProvider

**File**: `test/provider/search_filter_provider_test.dart`

**Test Cases:**
```dart
group('searchFilterProvider', () {
  test('initializes to empty filter', () { ... });
  test('updates query on user input', () { ... });
  test('updates status on chip tap', () { ... });
  test('resets to empty on clear', () { ... });
  test('copyWith preserves unmodified fields', () { ... });
});
```

**Setup:**
```dart
late ProviderContainer container;

setUp(() {
  container = ProviderContainer();
});

tearDown(() {
  container.dispose();
});

test('updates query on user input', () {
  // Read initial state
  final initial = container.read(searchFilterProvider);
  expect(initial.isEmpty, isTrue);
  
  // Update query
  container.read(searchFilterProvider.notifier).state =
      initial.copyWith(query: 'Công ty');
  
  // Verify state changed
  final updated = container.read(searchFilterProvider);
  expect(updated.query, 'Công ty');
  expect(updated.isEmpty, isFalse);
});
```

### Test 2: filteredCasesProvider

**File**: `test/provider/filtered_cases_provider_test.dart`

**Test Cases:**
```dart
group('filteredCasesProvider', () {
  test('returns top-level cases when filter empty', () { ... });
  test('calls searchCases when filter active', () { ... });
  test('passes correct parameters to database', () { ... });
  test('updates when searchFilterProvider changes', () { ... });
});
```

**Setup with Mock Database:**
```dart
class MockAppDatabase extends Mock implements AppDatabase {}

late ProviderContainer container;
late MockAppDatabase mockDb;

setUp(() {
  mockDb = MockAppDatabase();
  container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(mockDb),
    ],
  );
});

test('calls searchCases when filter active', () async {
  // Setup mock
  when(mockDb.searchCases('Công', status: any, parentCaseId: any))
      .thenAnswer((_) async => [/* mock cases */]);
  
  // Set filter
  container.read(searchFilterProvider.notifier).state =
      const SearchFilter(query: 'Công');
  
  // Read provider (triggers async call)
  final asyncValue = container.read(filteredCasesProvider);
  await asyncValue.when(
    data: (cases) {
      verify(mockDb.searchCases('Công', status: null, parentCaseId: null))
          .called(1);
    },
    loading: () => fail('Should not be loading'),
    error: (e, s) => fail('Should not error: $e'),
  );
});
```

---

## Phase 23.3 Details (Widget Tests)

### Test 1: Search Bar Reset

**File**: `test/widget/home_screen_search_test.dart`

**Test Cases:**
```dart
group('HomeScreen Search Bar', () {
  testWidgets('X button clears text and resets filter', (tester) async { ... });
  testWidgets('keyboard delete resets filter when empty', (tester) async { ... });
  testWidgets('debounces search input (300ms)', (tester) async { ... });
  testWidgets('X button cancels pending debounce', (tester) async { ... });
});
```

**Setup:**
```dart
testWidgets('X button clears text and resets filter', (tester) async {
  // GIVEN: HomeScreen with mock database
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(mockDb),
      ],
      child: MaterialApp(home: HomeScreen()),
    ),
  );
  
  // WHEN: Enter search text
  await tester.enterText(find.byType(TextField), 'Công ty');
  await tester.pump(Duration(milliseconds: 300)); // Wait for debounce
  
  // THEN: Filter should be active
  final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  expect(container.read(searchFilterProvider).query, 'Công ty');
  
  // WHEN: Tap X button
  await tester.tap(find.byIcon(Icons.clear));
  await tester.pump();
  
  // THEN: Text cleared and filter reset
  expect(find.text('Công ty'), findsNothing);
  expect(container.read(searchFilterProvider).isEmpty, isTrue);
});
```

### Test 2: Filter Chips

**File**: `test/widget/home_screen_filters_test.dart`

**Test Cases:**
```dart
group('HomeScreen Filter Chips', () {
  testWidgets('tapping Active chip filters by status', (tester) async { ... });
  testWidgets('tapping chip twice toggles on/off', (tester) async { ... });
  testWidgets('Clear Filters resets all filters', (tester) async { ... });
  testWidgets('filter count badge shows correct number', (tester) async { ... });
});
```

### Test 3: Empty States

**File**: `test/widget/home_screen_empty_states_test.dart`

**Test Cases:**
```dart
group('HomeScreen Empty States', () {
  testWidgets('shows "No cases yet" when no cases and no filters', (tester) async { ... });
  testWidgets('shows "No cases found" when filtering with no results', (tester) async { ... });
  testWidgets('switches to hierarchy when filter cleared', (tester) async { ... });
});
```

---

## Test Utilities

### database_test_helper.dart

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../../lib/src/data/database/database.dart';

/// Create in-memory database for testing
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Seed database with test cases
Future<void> seedTestCases(AppDatabase db, {
  int active = 0,
  int completed = 0,
  int archived = 0,
  int groups = 0,
}) async {
  for (int i = 0; i < active; i++) {
    await db.into(db.cases).insert(CasesCompanion.insert(
      name: 'Active Case $i',
      status: 'active',
      createdAt: DateTime.now(),
      isGroup: const Value(false),
    ));
  }
  // ... repeat for completed, archived, groups
}

/// Create case with specific properties
Future<String> createTestCase(AppDatabase db, {
  required String name,
  String? status,
  String? parentCaseId,
  bool isGroup = false,
}) async {
  return await db.into(db.cases).insert(CasesCompanion.insert(
    name: name,
    status: status ?? 'active',
    createdAt: DateTime.now(),
    isGroup: Value(isGroup),
    parentCaseId: Value(parentCaseId),
  ));
}
```

### provider_test_helper.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import '../../lib/src/data/database/database.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

/// Create ProviderContainer with mock database
ProviderContainer createTestContainer({
  AppDatabase? database,
}) {
  final mockDb = database ?? MockAppDatabase();
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(mockDb),
    ],
  );
}
```

---

## Success Criteria

### Code Coverage

| Category | Target | Measured |
|----------|--------|----------|
| Unit Tests | >80% | TBD |
| Provider Tests | >75% | TBD |
| Widget Tests | >60% | TBD |
| **Overall** | **>70%** | **TBD** |

### Test Quality

- ✅ All tests pass consistently (no flakiness)
- ✅ Tests are independent (can run in any order)
- ✅ Clear GIVEN/WHEN/THEN structure
- ✅ No production code changes (unless for testability)

### Documentation

- ✅ 3 sub-phase reports (23.1, 23.2, 23.3)
- ✅ Test helpers documented
- ✅ Test run instructions in reports

---

## Dependencies

### New Dependencies (Dev Only)

**Add to `pubspec.yaml`:**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  test: ^1.24.0             # Already in most projects
  mockito: ^5.4.0           # For mocks
  build_runner: ^2.4.0      # For mockito code generation
```

**Already Available:**
- `package:flutter_riverpod` (testing utilities included)
- `package:drift` (in-memory database support)

### No Production Changes

- ✅ No new prod dependencies
- ✅ No API changes
- ✅ Tests in `test/` directory only

---

## Risk Assessment

### Low Risk

- ✅ Tests don't affect production code
- ✅ Can skip tests temporarily if blocking deployment
- ✅ Tests can be added incrementally

### Medium Risk

- ⚠️ Mock setup complexity (Riverpod + Drift)
- ⚠️ Widget tests may be brittle (UI changes break tests)
- ⚠️ Time investment (6-8 hours)

### Mitigation

- Start with simple unit tests (highest ROI)
- Use shared test helpers (reduce duplication)
- Focus on logic, skip UI animations

---

## Phase 23 Timeline

### Phase 23.1: Unit Tests (2-3 hours)

1. Setup test infrastructure (30 min)
2. Write searchCases() tests (45 min)
3. Write Move Case tests (30 min)
4. Write DeleteGuard tests (30 min)
5. Write Quick Scan tests (30 min)
6. Report (15 min)

### Phase 23.2: Provider Tests (2-3 hours)

1. Setup mock database (30 min)
2. Write searchFilterProvider tests (45 min)
3. Write filteredCasesProvider tests (1 hour)
4. Write computed providers tests (30 min)
5. Report (15 min)

### Phase 23.3: Widget Tests (2-3 hours)

1. Setup widget test harness (30 min)
2. Write search bar tests (1 hour)
3. Write filter chips tests (45 min)
4. Write empty states tests (30 min)
5. Report (15 min)

**Total**: 6-9 hours (depending on complexity)

---

## Next Steps

### Immediate: Phase 23.1

1. Create `test/unit/database/search_cases_test.dart`
2. Implement 9 test cases for searchCases()
3. Verify all tests pass
4. Measure coverage
5. Write `Phase23_1_Unit_Tests_Report.md`

### After Phase 23.1

- Review Phase 23.1 report
- User decision: Continue to 23.2 or pause?
- If continue: Implement Phase 23.2 (Provider tests)

---

## Appendix: Test Command Reference

### Run All Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/unit/database/search_cases_test.dart
```

### Run with Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run in Watch Mode

```bash
flutter test --watch
```

---

**Phase 23 Plan Complete!** 📋

Ready to begin Phase 23.1 (Unit Tests) implementation.
