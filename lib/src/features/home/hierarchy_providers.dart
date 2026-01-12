import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart' as db;

/// Phase 21.4A: View model for case hierarchy display
class CaseViewModel {
  final db.Case caseData;
  final int? pageCount;    // For regular cases
  final int? childCount;   // For group cases
  final bool isExpanded;   // For group cases (UI state)
  final List<CaseViewModel>? children; // Loaded children if expanded

  const CaseViewModel({
    required this.caseData,
    this.pageCount,
    this.childCount,
    this.isExpanded = false,
    this.children,
  });

  bool get isGroup => caseData.isGroup;
  String get id => caseData.id;
  String get name => caseData.name;

  /// Create view model for regular case
  factory CaseViewModel.regularCase({
    required db.Case caseData,
    required int pageCount,
  }) {
    return CaseViewModel(
      caseData: caseData,
      pageCount: pageCount,
    );
  }

  /// Create view model for group case
  factory CaseViewModel.groupCase({
    required db.Case caseData,
    required int childCount,
    bool isExpanded = false,
    List<CaseViewModel>? children,
  }) {
    return CaseViewModel(
      caseData: caseData,
      childCount: childCount,
      isExpanded: isExpanded,
      children: children,
    );
  }

  /// Copy with new values
  CaseViewModel copyWith({
    bool? isExpanded,
    List<CaseViewModel>? children,
  }) {
    return CaseViewModel(
      caseData: caseData,
      pageCount: pageCount,
      childCount: childCount,
      isExpanded: isExpanded ?? this.isExpanded,
      children: children ?? this.children,
    );
  }
}

/// Phase 21.4A: State notifier for home screen hierarchy
class HomeScreenCasesNotifier extends StateNotifier<AsyncValue<List<CaseViewModel>>> {
  HomeScreenCasesNotifier(this.database) : super(const AsyncValue.loading()) {
    _load();
  }

  final db.AppDatabase database;

  /// Load top-level cases and build hierarchy
  Future<void> _load() async {
    state = const AsyncValue.loading();
    
    try {
      final topLevelCases = await database.getTopLevelCases();
      final viewModels = <CaseViewModel>[];

      for (final caseData in topLevelCases) {
        if (caseData.isGroup) {
          // Group case
          final childCount = await database.getChildCaseCount(caseData.id);
          viewModels.add(CaseViewModel.groupCase(
            caseData: caseData,
            childCount: childCount,
            isExpanded: false, // Default collapsed
          ));
        } else {
          // Regular top-level case
          final pages = await database.getPagesByCase(caseData.id);
          viewModels.add(CaseViewModel.regularCase(
            caseData: caseData,
            pageCount: pages.length,
          ));
        }
      }

      state = AsyncValue.data(viewModels);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh case list
  Future<void> refresh() async {
    await _load();
  }

  /// Toggle group expand/collapse
  /// Phase 21.4C: Added forceExpand parameter for breadcrumb navigation
  Future<void> toggleGroup(String groupId, {bool? forceExpand}) async {
    final currentState = state;
    if (currentState is! AsyncData<List<CaseViewModel>>) return;

    final cases = currentState.value;
    final groupIndex = cases.indexWhere((c) => c.id == groupId);
    if (groupIndex == -1) return;

    final group = cases[groupIndex];
    if (!group.isGroup) return;

    // Toggle expand state (or force expand if specified)
    final newExpanded = forceExpand ?? !group.isExpanded;
    List<CaseViewModel>? children;

    if (newExpanded && group.children == null) {
      // Load children if not already loaded
      final childCases = await database.getChildCases(groupId);
      children = [];
      
      for (final childCase in childCases) {
        final pages = await database.getPagesByCase(childCase.id);
        children.add(CaseViewModel.regularCase(
          caseData: childCase,
          pageCount: pages.length,
        ));
      }
    } else {
      children = group.children;
    }

    // Update state
    final updatedCases = List<CaseViewModel>.from(cases);
    updatedCases[groupIndex] = group.copyWith(
      isExpanded: newExpanded,
      children: children,
    );

    state = AsyncValue.data(updatedCases);
  }
}

/// Provider for home screen cases with hierarchy
final homeScreenCasesProvider = StateNotifierProvider<HomeScreenCasesNotifier, AsyncValue<List<CaseViewModel>>>(
  (ref) {
    final database = ref.watch(databaseProvider);
    return HomeScreenCasesNotifier(database);
  },
);

/// Singleton database provider (existing)
final databaseProvider = Provider<db.AppDatabase>((ref) {
  return db.AppDatabase();
});
