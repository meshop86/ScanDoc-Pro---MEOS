# Phase 24.0: Vietnamese Search Normalization - Plan & Analysis

**Phase**: 24.0 (Planning)  
**Date**: 2025-01-12  
**Status**: ✅ **COMPLETE**

---

## Executive Summary

Phase 24 adds Vietnamese search normalization to allow users to search Case names with or without diacritics (e.g., "hoa don" matches "hoá đơn").

**Approach**: Compute-on-query normalization (NO shadow columns)  
**Scope**: Case name search only (NOT OCR, NOT fuzzy search)  
**Impact**: Zero breaking changes to Phase 22 Search & Filter

---

## 1. Problem Statement

### 1.1 Current Behavior (Phase 22)

**Database Query:**
```dart
Future<List<Case>> searchCases(String? query, ...) async {
  if (query != null && query.trim().isNotEmpty) {
    final searchTerm = '%${query.trim()}%';
    stmt = stmt..where((c) => c.name.like(searchTerm));
  }
}
```

**SQL (SQLite LIKE):**
```sql
SELECT * FROM cases
WHERE is_group = 0
  AND name LIKE '%invoice%'
ORDER BY created_at DESC;
```

**Problem:**
- User types: `"hoa don"` (no diacritics)
- Database has: `"Hoá đơn"` (with diacritics)
- **Result**: ❌ No match (SQLite LIKE is diacritic-sensitive)

### 1.2 User Expectations

Vietnamese users expect:
- ✅ `"hoa don"` → matches `"Hoá đơn"`
- ✅ `"hoá đơn"` → matches `"Hoa don"` (reverse)
- ✅ `"dien thoai"` → matches `"Điện thoại"`
- ✅ `"hop dong"` → matches `"Hợp đồng"`

**Goal**: Diacritic-insensitive search (like Google Vietnamese search)

---

## 2. Solution Options

### Option A: Shadow Column (Normalized Storage)

**Approach:**
```dart
// Migration: Add normalized column
ALTER TABLE cases ADD COLUMN name_normalized TEXT;

// Trigger: Auto-update on insert/update
CREATE TRIGGER normalize_case_name
AFTER INSERT ON cases
BEGIN
  UPDATE cases
  SET name_normalized = removeDiacritics(NEW.name)
  WHERE id = NEW.id;
END;

// Search: Query normalized column
WHERE name_normalized LIKE '%hoa don%'
```

**Pros:**
- ✅ Fast query (no runtime normalization)
- ✅ Can add index on `name_normalized` for performance
- ✅ Query logic stays simple

**Cons:**
- ❌ Database migration required (adds column)
- ❌ Schema change (breaking change for existing installs)
- ❌ Storage overhead (~2x for case names)
- ❌ Drift doesn't support custom SQL functions in triggers easily
- ❌ Complex migration logic (need to normalize existing data)

**Verdict**: ❌ **TOO COMPLEX** for this feature

---

### Option B: Compute-on-Query (Runtime Normalization)

**Approach:**
```dart
// Normalize search query
final normalizedQuery = removeDiacritics(query.trim());

// Normalize database value in WHERE clause (requires custom SQL)
// SQLite doesn't have built-in removeDiacritics
// → Need to fetch all cases and filter in Dart
```

**Implementation Strategy:**
```dart
Future<List<Case>> searchCases(String? query, ...) async {
  // Step 1: Get all cases matching other filters (status, parent)
  var stmt = select(cases)..where((c) => c.isGroup.equals(false));
  
  if (status != null) {
    stmt = stmt..where((c) => c.status.equals(status.name));
  }
  
  if (parentCaseId == 'TOP_LEVEL') {
    stmt = stmt..where((c) => c.parentCaseId.isNull());
  } else if (parentCaseId != null) {
    stmt = stmt..where((c) => c.parentCaseId.equals(parentCaseId));
  }
  
  final allCases = await stmt.get();
  
  // Step 2: Filter by normalized name in Dart (if query provided)
  if (query != null && query.trim().isNotEmpty) {
    final normalizedQuery = removeDiacritics(query.trim().toLowerCase());
    
    return allCases.where((c) {
      final normalizedName = removeDiacritics(c.name.toLowerCase());
      return normalizedName.contains(normalizedQuery);
    }).toList();
  }
  
  return allCases;
}
```

**Pros:**
- ✅ No database migration
- ✅ No schema change
- ✅ Easy to implement
- ✅ Easy to test
- ✅ Can be toggled on/off easily

**Cons:**
- ⚠️ Slower for large datasets (fetch all → filter in Dart)
- ⚠️ Can't use SQL LIKE index optimization
- ⚠️ Need to normalize every case name on every search

**Performance Analysis:**
| Cases | SQL LIKE | Dart Filter | Overhead |
|-------|----------|-------------|----------|
| 100 | ~1ms | ~5ms | +4ms |
| 1000 | ~10ms | ~30ms | +20ms |
| 10000 | ~100ms | ~200ms | +100ms |

**Verdict**: ✅ **ACCEPTABLE** for MVP (most users have < 1000 cases)

---

### Option C: Hybrid (SQL LIKE + Dart Fallback)

**Approach:**
1. Try SQL LIKE first (fast path for exact match)
2. If no results, normalize and search in Dart (slow path)

**Implementation:**
```dart
Future<List<Case>> searchCases(String? query, ...) async {
  // Fast path: Try SQL LIKE first
  final exactMatches = await _searchExact(query, status, parentCaseId);
  if (exactMatches.isNotEmpty) return exactMatches;
  
  // Slow path: Normalize and filter in Dart
  return _searchNormalized(query, status, parentCaseId);
}
```

**Pros:**
- ✅ Fast for exact matches (most common case)
- ✅ Falls back to normalization if needed

**Cons:**
- ❌ Complex logic (two query paths)
- ❌ Still has worst-case performance of Option B
- ❌ Harder to test (need to test both paths)

**Verdict**: ❌ **PREMATURE OPTIMIZATION** (only useful if exact matches are common)

---

## 3. Chosen Solution: Option B (Compute-on-Query)

### 3.1 Rationale

**Decision Factors:**
1. **Simplicity**: No database migration, no schema change
2. **Phase 22 Compatibility**: Doesn't break existing search semantics
3. **Testability**: Easy to write unit tests for normalization
4. **Performance**: Acceptable for MVP (< 1000 cases)
5. **Reversibility**: Can be toggled off if issues arise

**Trade-offs Accepted:**
- ⚠️ Slower for large datasets (but most users have < 1000 cases)
- ⚠️ Can't use SQL indexes (but cases table is small)
- ⚠️ Runtime overhead (~20ms for 1000 cases)

**Future Migration Path:**
If performance becomes an issue (> 10,000 cases):
1. Add `name_normalized` shadow column
2. Create index on `name_normalized`
3. Migrate existing data
4. Switch to Option A

---

### 3.2 Implementation Steps

**Phase 24 Breakdown:**

**Phase 24.1: Normalization Function**
- Create `lib/src/utils/vietnamese_normalization.dart`
- Implement `removeDiacritics(String text)` function
- Unit tests for Vietnamese characters
- Unit tests for edge cases (empty, null, mixed)

**Phase 24.2: Search Integration**
- Modify `database.dart::searchCases()` to use normalization
- Keep SQL LIKE for non-query filters (status, parent)
- Add Dart filter for name matching
- Preserve Phase 22 behavior for non-Vietnamese search

**Phase 24.3: Regression Testing**
- Run existing Phase 23 tests (should all pass)
- Add new Vietnamese search tests
- Performance benchmark (100, 1000, 10000 cases)
- Manual testing on iOS simulator

---

## 4. Vietnamese Normalization Algorithm

### 4.1 Unicode Normalization (NFD)

**Approach**: Use Unicode NFD (Canonical Decomposition) to separate base characters from diacritics

**Example:**
```dart
String removeDiacritics(String text) {
  // Step 1: Normalize to NFD (decompose combined characters)
  // "ó" (U+00F3) → "o" (U+006F) + "́" (U+0301)
  final nfd = text.normalize(NFC: false, NFD: true);
  
  // Step 2: Remove combining diacritical marks (U+0300-U+036F)
  final regex = RegExp(r'[\u0300-\u036f]');
  final normalized = nfd.replaceAll(regex, '');
  
  // Step 3: Handle special Vietnamese characters not in NFD
  final specialChars = {
    'đ': 'd', 'Đ': 'D',  // Vietnamese d with stroke
  };
  
  return normalized.split('').map((char) => 
    specialChars[char] ?? char
  ).join('');
}
```

**Test Cases:**

| Input | NFD | After Regex | After Special | Output |
|-------|-----|-------------|---------------|--------|
| "Hoá đơn" | "Hoa\u0301 đơn" | "Hoa đon" | "Hoa don" | "hoa don" |
| "Điện thoại" | "Điện thoại" | "Điên thoai" | "Dien thoai" | "dien thoai" |
| "Hợp đồng" | "Hơ\u0323p đồng" | "Hơp đong" | "Hop dong" | "hop dong" |

---

### 4.2 Edge Cases

**Empty / Null:**
```dart
removeDiacritics('') → ''
removeDiacritics(null) → '' (or throw?)
```

**Mixed Vietnamese + English:**
```dart
removeDiacritics('Invoice Hoá đơn') → 'Invoice Hoa don'
```

**Numbers & Symbols:**
```dart
removeDiacritics('Hoá đơn #123') → 'Hoa don #123'
```

**Case Insensitive:**
```dart
removeDiacritics('HOÁ ĐƠN') → 'hoa don' (lowercase)
removeDiacritics('Hoá Đơn') → 'hoa don' (lowercase)
```

---

## 5. Database Query Changes

### 5.1 Current Implementation (Phase 22)

**File**: `lib/src/data/database/database.dart`

**Current Code:**
```dart
Future<List<Case>> searchCases(
  String? query, {
  CaseStatus? status,
  String? parentCaseId,
}) async {
  var stmt = select(cases)..where((c) => c.isGroup.equals(false));

  // Filter by name (case-insensitive partial match)
  if (query != null && query.trim().isNotEmpty) {
    final searchTerm = '%${query.trim()}%';
    stmt = stmt..where((c) => c.name.like(searchTerm));
  }

  // Filter by status
  if (status != null) {
    stmt = stmt..where((c) => c.status.equals(status.name));
  }

  // Filter by parent
  if (parentCaseId == 'TOP_LEVEL') {
    stmt = stmt..where((c) => c.parentCaseId.isNull());
  } else if (parentCaseId != null) {
    stmt = stmt..where((c) => c.parentCaseId.equals(parentCaseId));
  }

  return (stmt..orderBy([(c) => OrderingTerm.desc(c.createdAt)])).get();
}
```

**SQL Generated:**
```sql
SELECT * FROM cases
WHERE is_group = 0
  AND name LIKE '%invoice%'
  AND status = 'active'
  AND parent_case_id IS NULL
ORDER BY created_at DESC;
```

---

### 5.2 New Implementation (Phase 24.2)

**Changes:**
1. Move name filter from SQL to Dart
2. Keep other filters in SQL (for index optimization)
3. Normalize both query and case names

**New Code:**
```dart
Future<List<Case>> searchCases(
  String? query, {
  CaseStatus? status,
  String? parentCaseId,
}) async {
  // Start with base query (non-name filters only)
  var stmt = select(cases)..where((c) => c.isGroup.equals(false));

  // Filter by status (SQL)
  if (status != null) {
    stmt = stmt..where((c) => c.status.equals(status.name));
  }

  // Filter by parent (SQL)
  if (parentCaseId == 'TOP_LEVEL') {
    stmt = stmt..where((c) => c.parentCaseId.isNull());
  } else if (parentCaseId != null) {
    stmt = stmt..where((c) => c.parentCaseId.equals(parentCaseId));
  }

  // Execute SQL query
  stmt = stmt..orderBy([(c) => OrderingTerm.desc(c.createdAt)]);
  final allCases = await stmt.get();

  // Filter by name (Dart - with Vietnamese normalization)
  if (query != null && query.trim().isNotEmpty) {
    final normalizedQuery = removeDiacritics(query.trim().toLowerCase());
    
    return allCases.where((c) {
      final normalizedName = removeDiacritics(c.name.toLowerCase());
      return normalizedName.contains(normalizedQuery);
    }).toList();
  }

  return allCases;
}
```

**New SQL Generated:**
```sql
-- Phase 24: Name filter moved to Dart
SELECT * FROM cases
WHERE is_group = 0
  AND status = 'active'
  AND parent_case_id IS NULL
ORDER BY created_at DESC;

-- Then filter in Dart:
-- allCases.where((c) => 
--   removeDiacritics(c.name.toLowerCase()).contains('hoa don')
-- )
```

---

### 5.3 Behavior Comparison

| Query | Phase 22 (SQL LIKE) | Phase 24 (Dart Normalize) |
|-------|---------------------|---------------------------|
| `"invoice"` | ✅ Matches "Invoice 2024" | ✅ Matches "Invoice 2024" |
| `"Invoice"` | ✅ Matches "invoice" (case-insensitive) | ✅ Matches "invoice" (case-insensitive) |
| `"hoa don"` | ❌ No match "Hoá đơn" | ✅ Matches "Hoá đơn" ✨ |
| `"hoá đơn"` | ✅ Matches "Hoá đơn" | ✅ Matches "Hoá đơn" |
| `"dien thoai"` | ❌ No match "Điện thoại" | ✅ Matches "Điện thoại" ✨ |
| `"hop dong"` | ❌ No match "Hợp đồng" | ✅ Matches "Hợp đồng" ✨ |

**Key Changes:**
- ✅ Vietnamese search now works (with or without diacritics)
- ✅ English search still works (backward compatible)
- ✅ Case-insensitive behavior preserved
- ⚠️ Performance: +20ms for 1000 cases (acceptable)

---

## 6. Testing Strategy

### 6.1 Phase 24.1 Tests (Normalization Function)

**File**: `test/unit/utils/vietnamese_normalization_test.dart`

**Test Cases:**

**Group 1: Basic Normalization**
```dart
test('removes Vietnamese diacritics', () {
  expect(removeDiacritics('Hoá đơn'), 'hoa don');
  expect(removeDiacritics('Điện thoại'), 'dien thoai');
  expect(removeDiacritics('Hợp đồng'), 'hop dong');
});

test('handles uppercase', () {
  expect(removeDiacritics('HOÁ ĐƠN'), 'hoa don');
  expect(removeDiacritics('ĐIỆN THOẠI'), 'dien thoai');
});

test('preserves English', () {
  expect(removeDiacritics('Invoice'), 'invoice');
  expect(removeDiacritics('Contract'), 'contract');
});
```

**Group 2: Edge Cases**
```dart
test('handles empty string', () {
  expect(removeDiacritics(''), '');
});

test('handles mixed Vietnamese + English', () {
  expect(removeDiacritics('Invoice Hoá đơn'), 'invoice hoa don');
});

test('handles numbers and symbols', () {
  expect(removeDiacritics('Hoá đơn #123'), 'hoa don #123');
});

test('handles whitespace', () {
  expect(removeDiacritics('  Hoá đơn  '), 'hoa don'); // trim?
});
```

**Group 3: All Vietnamese Characters**
```dart
test('handles all Vietnamese vowels', () {
  // Test all tones: à á ả ã ạ, etc.
  expect(removeDiacritics('à á ả ã ạ'), 'a a a a a');
  expect(removeDiacritics('ă ằ ắ ẳ ẵ ặ'), 'a a a a a a');
  expect(removeDiacritics('â ầ ấ ẩ ẫ ậ'), 'a a a a a a');
  // ... (all vowels)
});

test('handles đ character', () {
  expect(removeDiacritics('đ'), 'd');
  expect(removeDiacritics('Đ'), 'd');
});
```

---

### 6.2 Phase 24.3 Tests (Search Integration)

**File**: `test/unit/database/search_cases_vietnamese_test.dart`

**Test Cases:**

**Group 1: Vietnamese Search**
```dart
test('searches without diacritics', () async {
  // GIVEN: Case with Vietnamese name
  await createCase(database, 'Hoá đơn 2024', 'active');
  
  // WHEN: Search without diacritics
  final results = await database.searchCases('hoa don');
  
  // THEN: Case found
  expect(results.length, 1);
  expect(results[0].name, 'Hoá đơn 2024');
});

test('searches with diacritics', () async {
  // GIVEN: Case without diacritics
  await createCase(database, 'Hoa don 2024', 'active');
  
  // WHEN: Search with diacritics
  final results = await database.searchCases('hoá đơn');
  
  // THEN: Case found
  expect(results.length, 1);
});

test('multiple Vietnamese cases', () async {
  // GIVEN: Multiple Vietnamese cases
  await createCase(database, 'Hoá đơn mua hàng', 'active');
  await createCase(database, 'Hoá đơn bán hàng', 'active');
  await createCase(database, 'Hợp đồng', 'active');
  
  // WHEN: Search "hoa don"
  final results = await database.searchCases('hoa don');
  
  // THEN: Both invoice cases found (not contract)
  expect(results.length, 2);
  expect(results.every((c) => c.name.contains('Hoá đơn')), true);
});
```

**Group 2: Regression Tests (Phase 22 Behavior)**
```dart
test('English search still works', () async {
  // GIVEN: English case
  await createCase(database, 'Invoice 2024', 'active');
  
  // WHEN: Search English
  final results = await database.searchCases('invoice');
  
  // THEN: Case found (backward compatible)
  expect(results.length, 1);
});

test('status filter still works', () async {
  // GIVEN: Active + completed Vietnamese cases
  await createCase(database, 'Hoá đơn A', 'active');
  await createCase(database, 'Hoá đơn B', 'completed');
  
  // WHEN: Search with status filter
  final results = await database.searchCases(
    'hoa don',
    status: CaseStatus.active,
  );
  
  // THEN: Only active case
  expect(results.length, 1);
  expect(results[0].status, 'active');
});

test('parent filter still works', () async {
  // GIVEN: Top-level + child Vietnamese cases
  await createCase(database, 'Hoá đơn A', 'active'); // top-level
  final groupId = await createCase(database, 'Group', 'active', isGroup: true);
  await createCase(database, 'Hoá đơn B', 'active', parentId: groupId); // child
  
  // WHEN: Search top-level only
  final results = await database.searchCases(
    'hoa don',
    parentCaseId: 'TOP_LEVEL',
  );
  
  // THEN: Only top-level case
  expect(results.length, 1);
  expect(results[0].name, 'Hoá đơn A');
});
```

**Group 3: Performance**
```dart
test('performance benchmark 1000 cases', () async {
  // GIVEN: 1000 Vietnamese cases
  for (int i = 0; i < 1000; i++) {
    await createCase(database, 'Hoá đơn $i', 'active');
  }
  
  // WHEN: Search
  final start = DateTime.now();
  final results = await database.searchCases('hoa don');
  final duration = DateTime.now().difference(start);
  
  // THEN: All found, performance acceptable
  expect(results.length, 1000);
  expect(duration.inMilliseconds, lessThan(100)); // < 100ms
});
```

---

## 7. Performance Analysis

### 7.1 Benchmark Scenarios

**Scenario 1: Small Dataset (100 cases)**
- SQL query: ~1ms
- Dart filter: ~3ms
- Total: ~4ms
- **Verdict**: ✅ Imperceptible to user

**Scenario 2: Medium Dataset (1000 cases)**
- SQL query: ~10ms
- Dart filter: ~20ms
- Total: ~30ms
- **Verdict**: ✅ Acceptable (< 100ms threshold)

**Scenario 3: Large Dataset (10,000 cases)**
- SQL query: ~100ms
- Dart filter: ~100ms
- Total: ~200ms
- **Verdict**: ⚠️ Noticeable but tolerable

**Scenario 4: Very Large Dataset (100,000 cases)**
- SQL query: ~1s
- Dart filter: ~1s
- Total: ~2s
- **Verdict**: ❌ Need shadow column optimization

---

### 7.2 Optimization Strategies (Future)

**If performance becomes an issue:**

**Option 1: Add Index on `name` Column**
```sql
CREATE INDEX idx_cases_name ON cases(name);
```
- ❌ Doesn't help (we're not using SQL LIKE anymore)

**Option 2: Add Shadow Column**
```sql
ALTER TABLE cases ADD COLUMN name_normalized TEXT;
CREATE INDEX idx_cases_name_normalized ON cases(name_normalized);
```
- ✅ Reduces Dart filtering to SQL query
- ❌ Requires database migration

**Option 3: Lazy Normalization (Cache)**
```dart
// Cache normalized names in memory
final Map<String, String> _normalizedCache = {};

String getCachedNormalized(String name) {
  return _normalizedCache.putIfAbsent(name, () => removeDiacritics(name));
}
```
- ✅ No database changes
- ❌ Memory overhead
- ❌ Cache invalidation complexity

**Recommendation**: Stick with Option B (compute-on-query) for now. Monitor performance in production. Migrate to shadow column if needed.

---

## 8. Provider & UI Impact

### 8.1 No Provider Changes Required

**File**: `lib/src/features/home/search_providers.dart`

**Current Code:**
```dart
final filteredCasesProvider = FutureProvider<List<Case>>((ref) async {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(searchFilterProvider);
  
  if (filter.isEmpty) {
    return db.getTopLevelCases();
  }
  
  return db.searchCases(
    filter.query,
    status: filter.status,
    parentCaseId: filter.parentCaseId,
  );
});
```

**After Phase 24:**
- ✅ No changes needed
- ✅ `db.searchCases()` signature unchanged
- ✅ Provider layer unaware of normalization
- ✅ UI layer unaware of normalization

**Reason**: Normalization is an internal implementation detail of `searchCases()`. Provider API stays the same.

---

### 8.2 No UI Changes Required

**File**: `lib/src/features/home/home_screen_new.dart`

**Current UI:**
```dart
TextField(
  controller: _searchController,
  decoration: InputDecoration(
    hintText: 'Search cases...',
    prefixIcon: const Icon(Icons.search),
    suffixIcon: _searchController.text.isNotEmpty
      ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: _clearSearch,
        )
      : null,
  ),
  onChanged: (value) {
    // Debounced update to searchFilterProvider
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchFilterProvider.notifier).state = SearchFilter(query: value);
    });
  },
)
```

**After Phase 24:**
- ✅ No UI changes
- ✅ User types "hoa don" → works
- ✅ User types "hoá đơn" → works
- ✅ English search → still works

---

## 9. Risks & Mitigation

### 9.1 Risk: Performance Degradation

**Risk**: Dart filtering slower than SQL LIKE for large datasets

**Likelihood**: Medium (if users have > 10,000 cases)

**Impact**: High (search feels slow, users complain)

**Mitigation**:
1. ✅ Add performance benchmark tests in Phase 24.3
2. ✅ Monitor production metrics (add analytics if needed)
3. ✅ Document migration path to shadow column (Option A)
4. ⚠️ Consider adding case count limit (e.g., warn users if > 5000 cases)

---

### 9.2 Risk: Normalization Bugs

**Risk**: `removeDiacritics()` doesn't handle all Vietnamese characters

**Likelihood**: Low (NFD covers most cases)

**Impact**: Medium (some searches fail)

**Mitigation**:
1. ✅ Comprehensive unit tests (all Vietnamese characters)
2. ✅ Manual testing with real Vietnamese names
3. ✅ Document known limitations
4. ✅ Easy to fix (just update normalization function)

---

### 9.3 Risk: Breaking Phase 22 Behavior

**Risk**: New implementation breaks existing search

**Likelihood**: Low (we have Phase 23 tests)

**Impact**: High (regression in stable feature)

**Mitigation**:
1. ✅ Run all Phase 23 tests after Phase 24.2
2. ✅ Add regression tests in Phase 24.3
3. ✅ Manual testing on iOS simulator
4. ✅ Can rollback easily (revert `searchCases()` implementation)

---

## 10. Success Criteria

### 10.1 Functional Requirements

- ✅ Vietnamese search works with or without diacritics
  - `"hoa don"` → matches `"Hoá đơn"`
  - `"hoá đơn"` → matches `"Hoa don"`
  - `"dien thoai"` → matches `"Điện thoại"`

- ✅ English search still works (backward compatible)
  - `"invoice"` → matches `"Invoice 2024"`

- ✅ Phase 22 filters still work
  - Status filter
  - Parent filter (TOP_LEVEL, group ID)
  - Combined filters

### 10.2 Non-Functional Requirements

- ✅ Performance: < 100ms for 1000 cases
- ✅ No database migration
- ✅ No UI changes
- ✅ No breaking API changes
- ✅ All Phase 23 tests pass
- ✅ New Vietnamese tests pass

### 10.3 Documentation Requirements

- ✅ Phase 24.0: Plan (this document)
- ✅ Phase 24.1: Normalization function report
- ✅ Phase 24.2: Search integration report
- ✅ Phase 24.3: Regression testing report
- ✅ Update README with Vietnamese search feature

---

## 11. Phase 24 Breakdown (Detailed)

### Phase 24.1: Normalization Function (1 session)

**File Created**: `lib/src/utils/vietnamese_normalization.dart`

**Tasks:**
- [ ] Create normalization utility file
- [ ] Implement `removeDiacritics(String text)` using NFD
- [ ] Handle special characters (đ, Đ)
- [ ] Add comprehensive unit tests
- [ ] Document algorithm and edge cases

**Deliverable**: `Phase24_1_Normalization_Function_Report.md`

**Time Estimate**: 1-2 hours

---

### Phase 24.2: Search Integration (1 session)

**File Modified**: `lib/src/data/database/database.dart`

**Tasks:**
- [ ] Refactor `searchCases()` to use Dart filtering
- [ ] Keep SQL filters for status/parent (performance)
- [ ] Import and use `removeDiacritics()` function
- [ ] Preserve backward compatibility
- [ ] Add inline documentation

**Deliverable**: `Phase24_2_Search_Integration_Report.md`

**Time Estimate**: 1-2 hours

---

### Phase 24.3: Regression Testing (1 session)

**Files Created**:
- `test/unit/database/search_cases_vietnamese_test.dart` (Vietnamese tests)
- `test/unit/database/search_cases_regression_test.dart` (Phase 22 regression)

**Tasks:**
- [ ] Write Vietnamese search tests
- [ ] Write Phase 22 regression tests
- [ ] Run all Phase 23 tests (should pass)
- [ ] Performance benchmark tests
- [ ] Manual testing on iOS simulator

**Deliverable**: `Phase24_3_Regression_Testing_Report.md`

**Time Estimate**: 2-3 hours

---

## 12. Limitations & Future Work

### 12.1 Known Limitations

**Not Implemented in Phase 24:**
- ❌ Fuzzy search (e.g., "hoadon" → "hoá đơn" without space)
- ❌ OCR text search (still Phase 8 scope)
- ❌ Search by label names
- ❌ Search by case ID
- ❌ Search by created date
- ❌ Full-text search across all fields

**Reason**: Phase 24 scope is ONLY Vietnamese normalization for case names

---

### 12.2 Future Enhancements (Post-Phase 24)

**Phase 25 (Optional): Advanced Search**
- Add fuzzy search (Levenshtein distance)
- Add search history
- Add search suggestions
- Add search analytics

**Phase 26 (Optional): Performance Optimization**
- Add shadow column if performance issue
- Add database index on `name_normalized`
- Migrate existing data
- A/B test performance improvement

**Phase 27 (Optional): OCR Search**
- Index OCR text in separate table
- Full-text search across OCR results
- Link OCR results to cases

---

## 13. Conclusion

### 13.1 Summary

Phase 24 adds Vietnamese search normalization using compute-on-query approach:
- ✅ No database migration
- ✅ No UI changes
- ✅ Backward compatible with Phase 22
- ✅ Acceptable performance (< 100ms for 1000 cases)
- ✅ Easy to test and maintain

### 13.2 Next Steps

1. ✅ **Approve Phase 24.0 Plan** (this document)
2. ⏭️ **Start Phase 24.1** (Normalization Function)
3. ⏭️ **Start Phase 24.2** (Search Integration)
4. ⏭️ **Start Phase 24.3** (Regression Testing)
5. ⏭️ **Close Phase 24** (Vietnamese Search Complete)

---

**Phase 24.0 Planning Complete!** ✅

Chosen approach: **Compute-on-query normalization** (no shadow column)  
Performance target: < 100ms for 1000 cases  
Breaking changes: **ZERO** (fully backward compatible)
