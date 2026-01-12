import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart' as db;
import '../../domain/models.dart' show CaseStatus;
import 'case_providers.dart' show databaseProvider;

// ============================================================================
// PHASE 22.2: SEARCH & FILTER PROVIDERS
// ============================================================================

/// Search and filter criteria for cases
///
/// Phase 22.2: Encapsulates all search/filter parameters in a single immutable model.
/// Used by [searchFilterProvider] to manage filter state and trigger [filteredCasesProvider] updates.
///
/// All fields are optional (null = not filtered):
/// - [query]: Partial name match (case-insensitive)
/// - [status]: Filter by case status (active/completed/archived)
/// - [parentCaseId]: Filter by parent ('TOP_LEVEL' for root cases, or specific group ID)
///
/// Example usage:
/// ```dart
/// // No filters (show default view)
/// const filter = SearchFilter();
///
/// // Search active cases
/// const filter = SearchFilter(
///   query: 'invoice',
///   status: CaseStatus.active,
/// );
///
/// // Show top-level completed cases
/// const filter = SearchFilter(
///   status: CaseStatus.completed,
///   parentCaseId: 'TOP_LEVEL',
/// );
/// ```
class SearchFilter {
  /// Search term to match against case name (null = no name filter)
  final String? query;

  /// Filter by case status (null = all statuses)
  final CaseStatus? status;

  /// Filter by parent case:
  /// - null: All cases (top-level + children)
  /// - 'TOP_LEVEL': Only top-level cases (no parent)
  /// - other: Only children of specified group
  final String? parentCaseId;

  const SearchFilter({
    this.query,
    this.status,
    this.parentCaseId,
  });

  /// Returns true if no filters are active (default view)
  ///
  /// Empty filter = show Phase 21 hierarchy (top-level cases including groups)
  /// Non-empty filter = search mode (only regular cases matching criteria)
  bool get isEmpty => query == null && status == null && parentCaseId == null;

  /// Returns true if user has entered any search/filter criteria
  bool get isActive => !isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchFilter &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          status == other.status &&
          parentCaseId == other.parentCaseId;

  @override
  int get hashCode => Object.hash(query, status, parentCaseId);

  @override
  String toString() {
    if (isEmpty) return 'SearchFilter.empty';
    return 'SearchFilter(query: $query, status: $status, parent: $parentCaseId)';
  }

  /// Create a copy with modified fields
  SearchFilter copyWith({
    String? query,
    CaseStatus? status,
    String? parentCaseId,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      status: status ?? this.status,
      parentCaseId: parentCaseId ?? this.parentCaseId,
    );
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Current search/filter state
///
/// Phase 22.2: Manages user's active search/filter criteria.
/// Changes to this provider automatically trigger [filteredCasesProvider] refresh.
///
/// Usage from UI:
/// ```dart
/// // Read current filter
/// final filter = ref.watch(searchFilterProvider);
///
/// // Update filter (triggers filteredCasesProvider refresh)
/// ref.read(searchFilterProvider.notifier).state = SearchFilter(
///   query: 'invoice',
///   status: CaseStatus.active,
/// );
///
/// // Clear all filters (return to default view)
/// ref.read(searchFilterProvider.notifier).state = const SearchFilter();
/// ```
final searchFilterProvider = StateProvider<SearchFilter>((ref) {
  return const SearchFilter(); // Default: no filters
});

/// Cases matching current search/filter criteria
///
/// Phase 22.2: Auto-refreshes when [searchFilterProvider] changes.
///
/// Behavior:
/// - If filter is empty → returns top-level cases (Phase 21 hierarchy with groups)
/// - If filter is active → returns regular cases matching criteria (no groups)
///
/// This preserves Phase 21 default view while enabling search/filter mode.
///
/// Usage from UI:
/// ```dart
/// final casesAsync = ref.watch(filteredCasesProvider);
///
/// casesAsync.when(
///   data: (cases) => ListView.builder(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => ErrorWidget(e),
/// );
/// ```
///
/// Invalidation:
/// - Auto-refreshes when searchFilterProvider changes
/// - Auto-refreshes when databaseProvider invalidates (after DB writes)
final filteredCasesProvider = FutureProvider<List<db.Case>>((ref) async {
  // Watch filter state (auto-refresh on change)
  final filter = ref.watch(searchFilterProvider);

  // Watch database (auto-refresh on invalidate)
  final database = ref.watch(databaseProvider);

  // Phase 22.2: Preserve Phase 21 default view
  if (filter.isEmpty) {
    // No filters = show Phase 21 hierarchy (top-level cases including groups)
    // This maintains existing home screen behavior when user hasn't searched
    return await database.getTopLevelCases();
  }

  // Phase 22.2: Search/filter mode
  // Returns only regular cases (not groups) matching criteria
  return await database.searchCases(
    filter.query,
    status: filter.status,
    parentCaseId: filter.parentCaseId,
  );
});

// ============================================================================
// HELPER PROVIDERS (Optional - for UI convenience)
// ============================================================================

/// Returns true if search/filter is currently active
///
/// Convenience provider for UI to show/hide "Clear Filters" button
///
/// Usage:
/// ```dart
/// final isFiltering = ref.watch(isFilterActiveProvider);
/// if (isFiltering) {
///   // Show "Clear Filters" button
/// }
/// ```
final isFilterActiveProvider = Provider<bool>((ref) {
  final filter = ref.watch(searchFilterProvider);
  return filter.isActive;
});

/// Count of active filters
///
/// Convenience provider for UI to show filter count badge
///
/// Usage:
/// ```dart
/// final count = ref.watch(activeFilterCountProvider);
/// // Show: "Filters (2)" if count > 0
/// ```
final activeFilterCountProvider = Provider<int>((ref) {
  final filter = ref.watch(searchFilterProvider);
  int count = 0;
  if (filter.query != null && filter.query!.trim().isNotEmpty) count++;
  if (filter.status != null) count++;
  if (filter.parentCaseId != null) count++;
  return count;
});
