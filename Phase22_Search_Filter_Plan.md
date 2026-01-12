# PHASE 22 — SEARCH & FILTER (NON-OCR)

**Date:** 11/01/2026  
**Status:** 📋 PLANNING  
**Engineer:** Flutter + Drift Team

---

## CONTEXT

### Phase 21 Complete ✅
- Case Hierarchy stable (top-level + 1-level groups)
- Move operations working
- Quick Scan integrated

### User Pain Point 🎯
- Hiện tại Home screen chỉ show tất cả cases
- User phải scroll để tìm case cần thiết
- Không có cách filter theo status hoặc group
- Khó tìm case khi số lượng case nhiều

---

## OBJECTIVES

### Primary Goals
1. **Search by Name:** Tìm case theo `case.name` (DB query, not UI filter)
2. **Filter by Status:** Active / Completed / Archived
3. **Filter by Group:** Top-level / Specific group
4. **UX:** Search bar, clear filters, empty states

### Non-Goals (Out of Scope)
- ❌ OCR search (nội dung text trong hình)
- ❌ Search theo date range
- ❌ Advanced filters (tags, custom fields)
- ❌ Full-text search
- ❌ Refactor Case Hierarchy
- ❌ Scan Engine changes

---

## CURRENT STATE ANALYSIS

### Database Schema (Phase 21)
```dart
class Cases extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();                    // ← SEARCH TARGET
  TextColumn get description => text().nullable()();
  TextColumn get status => text()();                  // ← FILTER TARGET
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get ownerUserId => text()();
  TextColumn get parentCaseId => text().nullable()(); // ← FILTER TARGET
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
}
```

### Available Status Values
```dart
enum CaseStatus { active, completed, archived }
```

### Existing Queries (Phase 21)
```dart
// database.dart
Future<List<Case>> getTopLevelCases()        // WHERE parentCaseId IS NULL
Future<List<Case>> getGroupCases()            // WHERE isGroup = TRUE
Future<List<Case>> getChildCases(String id)   // WHERE parentCaseId = id
```

### Home Screen Provider
```dart
// home_screen_new.dart uses:
ref.watch(homeScreenCasesProvider)  // StateNotifierProvider
```

---

## PHASE 22 BREAKDOWN

### Sub-Phase 22.1: Database Query Layer
**File:** `lib/src/data/database/database.dart`  
**Duration:** 1 session

**Tasks:**
- [ ] Add `searchCases(String query, {status, parentCaseId})` query
- [ ] Support partial match: `name LIKE %query%` (case-insensitive)
- [ ] Support filtering by status
- [ ] Support filtering by parentCaseId (null = top-level)
- [ ] Add tests for edge cases (empty query, null filters)

**SQL Preview:**
```dart
Future<List<Case>> searchCases(
  String? query,
  {CaseStatus? status, String? parentCaseId}
) {
  var stmt = select(cases);
  
  // Search by name (if provided)
  if (query != null && query.isNotEmpty) {
    stmt = stmt..where((c) => c.name.like('%$query%'));
  }
  
  // Filter by status (if provided)
  if (status != null) {
    stmt = stmt..where((c) => c.status.equals(status.name));
  }
  
  // Filter by parent (if explicitly set)
  if (parentCaseId == 'TOP_LEVEL') {
    stmt = stmt..where((c) => c.parentCaseId.isNull());
  } else if (parentCaseId != null) {
    stmt = stmt..where((c) => c.parentCaseId.equals(parentCaseId));
  }
  
  return (stmt..orderBy([(c) => OrderingTerm.desc(c.createdAt)])).get();
}
```

**Deliverable:** `Phase22_1_Database_Queries_Report.md`

---

### Sub-Phase 22.2: Provider Layer & State Management
**File:** `lib/src/features/home/search_providers.dart` (new)  
**Duration:** 1 session

**Tasks:**
- [ ] Create `SearchFilter` model (query, status, groupId)
- [ ] Create `searchFilterProvider` (StateProvider)
- [ ] Create `filteredCasesProvider` (FutureProvider using searchCases)
- [ ] Handle empty states (no results, no query)
- [ ] Integrate with existing `homeScreenCasesProvider`

**Provider Architecture:**
```dart
// search_providers.dart

/// Search/filter criteria
class SearchFilter {
  final String? query;
  final CaseStatus? status;
  final String? groupId;  // null = all, 'TOP_LEVEL' = top-level only
  
  const SearchFilter({this.query, this.status, this.groupId});
  
  bool get isEmpty => query == null && status == null && groupId == null;
}

/// Current search filter state
final searchFilterProvider = StateProvider<SearchFilter>(
  (ref) => const SearchFilter(),
);

/// Cases matching current filter
final filteredCasesProvider = FutureProvider<List<Case>>((ref) async {
  final filter = ref.watch(searchFilterProvider);
  final db = ref.watch(databaseProvider);
  
  if (filter.isEmpty) {
    // No filter = show top-level cases (default view)
    return db.getTopLevelCases();
  }
  
  return db.searchCases(
    filter.query,
    status: filter.status,
    parentCaseId: filter.groupId,
  );
});
```

**Deliverable:** `Phase22_2_Provider_Layer_Report.md`

---

### Sub-Phase 22.3: UI Implementation
**File:** `lib/src/features/home/home_screen_new.dart`  
**Duration:** 1 session

**Tasks:**
- [ ] Add search bar in AppBar
- [ ] Add filter chips (Status, Group)
- [ ] Add "Clear All Filters" button
- [ ] Empty state for "No results"
- [ ] Show active filters count
- [ ] Preserve scroll position after filter

**UI Mockup:**
```
┌─────────────────────────────────────┐
│ ScanDoc Pro                      ⚙️ │
│ ┌───────────────────────────────┐   │
│ │ 🔍 Search cases...           │   │
│ └───────────────────────────────┘   │
│                                     │
│ Filters: ┌─────────┬─────────────┐ │
│         │ Active ✓ │ Top-level ✓ │  │
│         └─────────┴─────────────┘  │
│ Clear filters (2 active)            │
│ ─────────────────────────────────── │
│ 📄 Invoice Case 2024               │
│    5 pages · Active                 │
│ ─────────────────────────────────── │
│ 📄 Contract Documents              │
│    12 pages · Completed             │
│ ─────────────────────────────────── │
│                 +                   │
└─────────────────────────────────────┘
```

**Widget Structure:**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final filter = ref.watch(searchFilterProvider);
  final casesAsync = ref.watch(filteredCasesProvider);
  
  return Scaffold(
    appBar: AppBar(
      title: _buildSearchBar(ref),  // New
    ),
    body: Column(
      children: [
        _buildFilterChips(ref, filter),  // New
        if (!filter.isEmpty) _buildClearFiltersButton(ref),  // New
        Expanded(
          child: casesAsync.when(
            data: (cases) => cases.isEmpty
              ? _buildEmptyState(filter)  // New
              : _buildCaseList(cases),
            loading: () => _buildLoadingState(),
            error: (e, st) => _buildErrorState(e),
          ),
        ),
      ],
    ),
  );
}
```

**Empty States:**
```dart
Widget _buildEmptyState(SearchFilter filter) {
  if (!filter.isEmpty) {
    // User searched/filtered but no results
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text('No cases found', style: TextStyle(fontSize: 20)),
          SizedBox(height: 8),
          Text('Try different search terms or filters'),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.read(searchFilterProvider.notifier)
                .state = SearchFilter(),
            child: Text('Clear Filters'),
          ),
        ],
      ),
    );
  } else {
    // No cases in database at all
    return _buildWelcomeState();
  }
}
```

**Deliverable:** `Phase22_3_UI_Implementation_Report.md`

---

### Sub-Phase 22.4: Edge Cases & Polish
**Duration:** 1 session

**Tasks:**
- [ ] Test with 0 cases
- [ ] Test with 1000+ cases
- [ ] Test search with special characters
- [ ] Test Vietnamese diacritics (á, à, ả, ã, ạ)
- [ ] Test clear search while loading
- [ ] Test navigation preserves filter state
- [ ] Test filter combination edge cases
- [ ] Performance testing (query time < 100ms)

**Vietnamese Search Support:**
```dart
// Option 1: Case-insensitive LIKE (default SQLite)
where((c) => c.name.like('%$query%'))

// Option 2: If needed, normalize Vietnamese
// (Remove diacritics for search matching)
String _normalizeVietnamese(String text) {
  // 'café' → 'cafe'
  // 'Hồ Chí Minh' → 'Ho Chi Minh'
  return text.toLowerCase()
    .replaceAll(RegExp(r'[áàảãạăắằẳẵặâấầẩẫậ]'), 'a')
    .replaceAll(RegExp(r'[éèẻẽẹêếềểễệ]'), 'e')
    // ... etc
}
```

**Deliverable:** `Phase22_4_Edge_Cases_Report.md`

---

## TECHNICAL DECISIONS

### 1. Search Strategy: DB Query vs UI Filter

**❌ Option A: Filter in UI**
```dart
// BAD: Load all cases, filter in memory
final allCases = await db.getAllCases();
final filtered = allCases.where((c) => c.name.contains(query));
```
**Problems:**
- Load 1000+ cases from DB (slow)
- Filter in UI thread (blocks rendering)
- Memory intensive

**✅ Option B: DB Query (CHOSEN)**
```dart
// GOOD: Query only matching cases
final filtered = await db.searchCases(query);
```
**Benefits:**
- SQLite indexed search (fast)
- Only load needed data
- Scales to 10,000+ cases

---

### 2. Filter State Management

**✅ Use StateProvider + FutureProvider (CHOSEN)**
```dart
final searchFilterProvider = StateProvider<SearchFilter>(...);
final filteredCasesProvider = FutureProvider((ref) {
  final filter = ref.watch(searchFilterProvider);
  return db.searchCases(filter.query, ...);
});
```

**Benefits:**
- Filter changes auto-trigger query
- Loading states handled by FutureProvider
- Easy to test

**Alternative (rejected):**
- StateNotifier: Overkill for simple filter state
- Manual state: Too much boilerplate

---

### 3. Search Debouncing

**✅ Debounce search input (CHOSEN)**
```dart
Timer? _debounceTimer;

void _onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 300), () {
    ref.read(searchFilterProvider.notifier).state = 
      SearchFilter(query: query);
  });
}
```

**Why:**
- Avoid query per keystroke
- Better UX (wait for user to finish typing)
- Reduce DB load

---

### 4. Filter Persistence

**⏸️ Phase 22: No Persistence (KISS)**
- Filter resets on app restart
- Simpler implementation
- Faster to ship

**🔮 Future Phase:**
- Save filter to SharedPreferences
- Restore on app launch
- Per-screen filter memory

---

## INVARIANTS TO PRESERVE

### From Phase 21 (Case Hierarchy)
- ✅ Groups cannot be moved into groups
- ✅ Groups cannot be scanned/exported
- ✅ Search/filter does NOT change hierarchy rules
- ✅ `isGroup` field respected in search results

### From Phase 20 (Export)
- ✅ Search does not affect export logic
- ✅ Filter does not affect "Export All" scope

### From Phase 13 (Core)
- ✅ Case status transitions (active → completed → archived)
- ✅ Only active cases shown by default (unless filtered)

---

## SUCCESS METRICS

### Performance
- [ ] Search query < 100ms for 1000 cases
- [ ] UI remains responsive during search
- [ ] No frame drops when typing

### UX
- [ ] Can find case in < 3 taps
- [ ] Clear feedback when no results
- [ ] Filter state visible at all times

### Code Quality
- [ ] 0 compilation errors
- [ ] No breaking changes to existing code
- [ ] All providers properly invalidated
- [ ] Empty states for all filter combinations

---

## TESTING CHECKLIST

### Unit Tests (database.dart)
- [ ] Search with empty query returns all cases
- [ ] Search with query filters by name
- [ ] Filter by status works
- [ ] Filter by group works
- [ ] Combined filters work (query + status + group)
- [ ] Case-insensitive search
- [ ] Special characters in search

### Integration Tests (Providers)
- [ ] searchFilterProvider updates
- [ ] filteredCasesProvider reacts to filter changes
- [ ] Loading states shown correctly
- [ ] Error states handled

### E2E Tests (UI)
- [ ] Type in search bar → Results update
- [ ] Select status filter → Results update
- [ ] Select group filter → Results update
- [ ] Clear filters → Show default view
- [ ] Empty state shown when no results
- [ ] Can create case from empty state

---

## RISK ANALYSIS

### High Risk
- ⚠️ **Vietnamese diacritics:** SQLite LIKE may not match 'ô' with 'o'
  - **Mitigation:** Test thoroughly, add normalization if needed

### Medium Risk
- ⚠️ **Performance with 1000+ cases:** Query may be slow
  - **Mitigation:** Add indexes on `name`, `status`, `parentCaseId`
  - **SQL:** `CREATE INDEX idx_cases_name ON cases(name COLLATE NOCASE)`

- ⚠️ **Filter state lost on navigation:** User frustration
  - **Mitigation:** Document clearly, add persistence in future phase

### Low Risk
- ⚠️ **Search debouncing timing:** Too fast = too many queries, too slow = feels laggy
  - **Mitigation:** Test with 300ms, adjust if needed

---

## DEVELOPMENT WORKFLOW

### Phase 22.1 (Database) - DAY 1
1. ✅ Read this plan document
2. → Implement `searchCases()` in database.dart
3. → Add SQL comments explaining query
4. → Test with various filter combinations
5. → Write Phase22_1 report
6. → Git commit: `[Phase 22.1] Add search & filter queries`

### Phase 22.2 (Providers) - DAY 2
1. ✅ Read Phase22_1 report
2. → Create search_providers.dart
3. → Implement SearchFilter model
4. → Implement searchFilterProvider & filteredCasesProvider
5. → Write Phase22_2 report
6. → Git commit: `[Phase 22.2] Add search/filter state management`

### Phase 22.3 (UI) - DAY 3
1. ✅ Read Phase22_2 report
2. → Add search bar to home_screen_new.dart
3. → Add filter chips
4. → Add empty states
5. → Test UX flows
6. → Write Phase22_3 report
7. → Git commit: `[Phase 22.3] Add search/filter UI`

### Phase 22.4 (Polish) - DAY 4
1. ✅ Read Phase22_3 report
2. → Test edge cases (checklist above)
3. → Fix bugs found during testing
4. → Performance optimization if needed
5. → Write Phase22_4 report
6. → Git commit: `[Phase 22.4] Search/filter polish & edge cases`

### Phase 22 Closure - DAY 5
1. ✅ Review all sub-phase reports
2. → Execute full test suite
3. → Write Phase22_Final_Report.md
4. → Update README.md
5. → Tag release: `v1.22.0`

---

## FILE STRUCTURE

```
lib/src/
├── data/database/
│   └── database.dart            # Modified: Add searchCases()
├── features/home/
│   ├── home_screen_new.dart     # Modified: Add search UI
│   ├── search_providers.dart    # NEW: Search state management
│   └── case_providers.dart      # No changes (read only)
└── domain/
    └── models.dart              # No changes

reports/
├── Phase22_Search_Filter_Plan.md     # This file
├── Phase22_1_Database_Queries_Report.md
├── Phase22_2_Provider_Layer_Report.md
├── Phase22_3_UI_Implementation_Report.md
├── Phase22_4_Edge_Cases_Report.md
└── Phase22_Final_Report.md
```

---

## DEPENDENCIES

### No New Packages Required ✅
- Drift: Already installed (database)
- Riverpod: Already installed (state management)
- Flutter Material: Already used (UI)

### No Breaking Changes ✅
- Existing providers remain unchanged
- `homeScreenCasesProvider` still works (default view)
- `filteredCasesProvider` is additive, not replacement

---

## DOCUMENTATION PLAN

### Code Comments
```dart
/// Phase 22.1: Search and filter cases by name, status, and group
/// 
/// Example: Search for active cases in a specific group
/// ```dart
/// final cases = await db.searchCases(
///   'invoice',
///   status: CaseStatus.active,
///   parentCaseId: 'group-123',
/// );
/// ```
Future<List<Case>> searchCases(
  String? query,
  {CaseStatus? status, String? parentCaseId}
) { ... }
```

### User Documentation
- Add "Search & Filter" section to README.md
- Screenshot of search bar + filters
- Explain filter combinations

---

## PHASE 22 COMPLETION CRITERIA

### Must Have ✅
- [x] Plan approved (this document)
- [ ] Sub-phase 22.1 complete + report
- [ ] Sub-phase 22.2 complete + report
- [ ] Sub-phase 22.3 complete + report
- [ ] Sub-phase 22.4 complete + report
- [ ] All tests passing
- [ ] 0 compilation errors
- [ ] Performance benchmarks met
- [ ] Final report written

### Nice to Have 🔮 (Future Phases)
- [ ] Filter persistence (SharedPreferences)
- [ ] Search history
- [ ] Recent searches dropdown
- [ ] Fuzzy search (typo tolerance)
- [ ] Multi-language search normalization

---

## NEXT ACTIONS

### Immediate (Right Now)
1. ✅ User reviews this plan
2. ✅ User approves/requests changes
3. → Start Phase 22.1 (Database Queries)

### After Plan Approval
```bash
# Engineer will ask:
"Phase 22 plan ready. Start Phase 22.1 (Database Queries)?"

# User confirms:
"Yes" → Begin implementation
"Wait" → Discuss plan revisions
```

---

## REFERENCES

### Phase 21 (Hierarchy)
- Schema: `Cases.parentCaseId`, `Cases.isGroup`
- Queries: `getTopLevelCases()`, `getChildCases()`
- UI: Group case tiles, expand/collapse

### Phase 20 (Export)
- Export does not interact with search
- Search results can be exported normally

### Phase 13 (Core)
- Case model: `id`, `name`, `status`, `createdAt`
- Status enum: `active`, `completed`, `archived`

---

## COMMUNICATION PROTOCOL

### During Development
- **Report only:** Each sub-phase generates detailed report
- **Chat summary:** Keep chat messages brief (2-3 lines)
- **Status updates:** "Phase 22.X complete, see report for details"

### Report Structure (Per Sub-Phase)
```markdown
# PHASE 22.X — [Title]
- What changed
- Why (technical reasoning)
- How to test
- Next sub-phase preview
```

---

## APPROVAL SIGN-OFF

**Plan Author:** GitHub Copilot (Flutter + Drift Engineer)  
**Date:** 11/01/2026  
**Status:** ⏸️ AWAITING USER APPROVAL

**User Approval:**
- [ ] Plan reviewed
- [ ] Scope acceptable
- [ ] Ready to proceed with Phase 22.1

**Approved by:** _______________________  
**Date:** _______________________

---

✅ **PLAN COMPLETE — READY FOR PHASE 22.1 KICKOFF**
