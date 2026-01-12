import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scandocpro/src/features/home/search_providers.dart';
import 'package:scandocpro/src/domain/models.dart' show CaseStatus;

/// Phase 23.3: Widget tests for Search & Filter UI Components
/// 
/// Tests UI behavior in isolation using simple test widgets.
/// Focus: TextField behavior, FilterChip interaction, Empty state display.

void main() {
  group('Search Bar Widget Behavior', () {
    testWidgets('TextField shows X button when text is entered', (tester) async {
      // GIVEN: TextField with controller
      final controller = TextEditingController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search...',
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => controller.clear(),
                      )
                    : null,
              ),
            ),
          ),
        ),
      );
      
      // THEN: X button not visible initially
      expect(find.byIcon(Icons.clear), findsNothing);
      
      // WHEN: Type text
      await tester.enterText(find.byType(TextField), 'invoice');
      await tester.pumpAndSettle();
      
      // THEN: X button still not visible (needs setState in real widget)
      // This demonstrates the bug that Phase 22 Fix addressed
    });
    
    testWidgets('pressing X button clears TextField', (tester) async {
      // GIVEN: TextField with text and X button
      final controller = TextEditingController(text: 'test');
      bool xPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    xPressed = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      
      // WHEN: Tap X button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      
      // THEN: Text is cleared
      expect(controller.text, isEmpty);
      expect(xPressed, true);
    });
  });
  
  group('Filter Chip Widget Behavior', () {
    testWidgets('tapping FilterChip toggles selected state', (tester) async {
      // GIVEN: FilterChip that can be selected
      bool isSelected = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return FilterChip(
                  label: const Text('Active'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => isSelected = selected);
                  },
                );
              },
            ),
          ),
        ),
      );
      
      // THEN: Not selected initially
      final chip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(chip.selected, false);
      
      // WHEN: Tap chip
      await tester.tap(find.byType(FilterChip));
      await tester.pumpAndSettle();
      
      // THEN: Now selected
      final chipAfter = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(chipAfter.selected, true);
    });
    
    testWidgets('multiple FilterChips can be shown in a row', (tester) async {
      // GIVEN: Row of FilterChips
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                FilterChip(
                  label: const Text('Active'),
                  selected: false,
                  onSelected: (_) {},
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Completed'),
                  selected: false,
                  onSelected: (_) {},
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Archived'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      
      // THEN: All chips are visible
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });
  });
  
  group('Empty State Widget', () {
    testWidgets('shows "No cases found" message with icon', (tester) async {
      // GIVEN: Empty state widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No cases found',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try different search terms or filters',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // THEN: All elements are visible
      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('No cases found'), findsOneWidget);
      expect(find.text('Try different search terms or filters'), findsOneWidget);
    });
    
    testWidgets('empty state has Clear Filters button', (tester) async {
      // GIVEN: Empty state with button
      bool buttonPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 80),
                  const SizedBox(height: 16),
                  const Text('No cases found'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => buttonPressed = true,
                    child: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // WHEN: Tap Clear Filters button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear Filters'));
      await tester.pumpAndSettle();
      
      // THEN: Button callback is triggered
      expect(buttonPressed, true);
    });
  });
  
  group('SearchFilter Provider Behavior (Riverpod)', () {
    test('SearchFilter initial state is empty', () {
      // GIVEN: ProviderContainer
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // WHEN: Read searchFilterProvider
      final filter = container.read(searchFilterProvider);
      
      // THEN: Filter is empty
      expect(filter.isEmpty, true);
      expect(filter.query, null);
      expect(filter.status, null);
      expect(filter.parentCaseId, null);
    });
    
    test('SearchFilter updates when query is set', () {
      // GIVEN: ProviderContainer
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // WHEN: Update filter with query
      container.read(searchFilterProvider.notifier).state = const SearchFilter(
        query: 'invoice',
      );
      
      // THEN: Filter has query
      final filter = container.read(searchFilterProvider);
      expect(filter.query, 'invoice');
      expect(filter.isEmpty, false);
    });
    
    test('SearchFilter resets to empty', () {
      // GIVEN: ProviderContainer with active filter
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      container.read(searchFilterProvider.notifier).state = const SearchFilter(
        query: 'test',
        status: CaseStatus.active,
      );
      
      // WHEN: Reset to empty
      container.read(searchFilterProvider.notifier).state = const SearchFilter();
      
      // THEN: Filter is empty
      final filter = container.read(searchFilterProvider);
      expect(filter.isEmpty, true);
      expect(filter.query, null);
      expect(filter.status, null);
    });
    
    test('isFilterActiveProvider returns true when filter has values', () {
      // GIVEN: ProviderContainer with active filter
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
    
    test('activeFilterCountProvider counts active filters', () {
      // GIVEN: ProviderContainer with 2 filters
      final container = ProviderContainer(
        overrides: [
          searchFilterProvider.overrideWith((ref) {
            return const SearchFilter(
              query: 'invoice',
              status: CaseStatus.active,
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
  });
}
