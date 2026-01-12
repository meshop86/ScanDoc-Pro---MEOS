import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../../data/database/database.dart' as db;
import '../../domain/models.dart' show CaseStatus;
import '../../routing/routes.dart';
import '../../services/guards/delete_guard.dart';
import 'case_providers.dart' hide databaseProvider;
import 'hierarchy_providers.dart';
import 'search_providers.dart';

/// Phase 13.1: Home Screen - Case Library (Professional Document Scanner)
/// Phase 22.4: Converted to StatefulConsumerWidget for debounce support
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Phase 22.4: Debounce timer for search input
  Timer? _searchDebounceTimer;
  
  // Phase 22 Fix: TextEditingController for search bar
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Phase 21.4B: Show create options (Group or Case)
  Future<void> _showCreateOptions(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create New',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder, color: Colors.amber),
              ),
              title: const Text('Create Group'),
              subtitle: const Text('Organize multiple cases'),
              onTap: () => Navigator.pop(ctx, 'group'),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description, color: Colors.blue),
              ),
              title: const Text('Create Case'),
              subtitle: const Text('Scan documents'),
              onTap: () => Navigator.pop(ctx, 'case'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (context.mounted) {
      if (choice == 'group') {
        await _createNewGroup(context, ref);
      } else if (choice == 'case') {
        await _createNewCase(context, ref);
      }
    }
  }

  /// Phase 21.4B: Create new group case
  Future<void> _createNewGroup(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder, color: Colors.amber),
            SizedBox(width: 8),
            Text('Create Group'),
          ],
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'e.g., Personal Documents',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    
    final groupName = nameController.text.trim();
    if (groupName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a group name')),
        );
      }
      return;
    }

    // Create group case in database
    try {
      final database = ref.read(databaseProvider);
      final groupId = const Uuid().v4();
      final now = DateTime.now();
      
      await database.createCase(
        db.CasesCompanion(
          id: drift.Value(groupId),
          name: drift.Value(groupName),
          description: const drift.Value(''),
          status: const drift.Value('active'),
          isGroup: const drift.Value(true), // Phase 21.4B: Mark as group
          parentCaseId: const drift.Value(null), // Phase 21.4B: Groups are top-level
          createdAt: drift.Value(now),
          ownerUserId: const drift.Value('default'),
        ),
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Created group: $groupName'),
            backgroundColor: Colors.green,
          ),
        );
        // Phase 21.4B: Refresh hierarchy provider
        await ref.read(homeScreenCasesProvider.notifier).refresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Phase 21.4B: Create new case (with optional group selection)
  Future<void> _createNewCase(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    // Step 1: Get case name
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description, color: Colors.blue),
            SizedBox(width: 8),
            Text('Create Case'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Case Name',
                hintText: 'e.g., House Purchase Documents',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add notes about this case',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    
    final caseName = nameController.text.trim();
    if (caseName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a case name')),
        );
      }
      return;
    }

    // Step 2: Select group (optional)
    String? selectedGroupId;
    
    if (context.mounted) {
      final database = ref.read(databaseProvider);
      final groups = await database.getGroupCases();
      
      if (groups.isNotEmpty) {
        selectedGroupId = await showDialog<String?>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Add to Group?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_open, color: Colors.grey),
                  title: const Text('No Group (Top-level)'),
                  onTap: () => Navigator.pop(ctx, null),
                ),
                const Divider(),
                ...groups.map((group) => ListTile(
                  leading: const Icon(Icons.folder, color: Colors.amber),
                  title: Text(group.name),
                  onTap: () => Navigator.pop(ctx, group.id),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
        
        if (selectedGroupId == 'cancel') return;
      }
    }

    // Step 3: Create case in database
    try {
      final database = ref.read(databaseProvider);
      final caseId = const Uuid().v4();
      final now = DateTime.now();
      
      await database.createCase(
        db.CasesCompanion(
          id: drift.Value(caseId),
          name: drift.Value(caseName),
          description: drift.Value(descController.text.trim()),
          status: const drift.Value('active'),
          isGroup: const drift.Value(false), // Phase 21.4B: Regular case
          parentCaseId: drift.Value(selectedGroupId), // Phase 21.4B: Optional parent
          createdAt: drift.Value(now),
          ownerUserId: const drift.Value('default'),
        ),
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Created case: $caseName'),
            backgroundColor: Colors.green,
          ),
        );
        // Phase 21.4B: Refresh hierarchy provider
        await ref.read(homeScreenCasesProvider.notifier).refresh();
        
        // Phase 21.4B: Navigate to case detail
        context.push('${Routes.caseDetail}/$caseId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phase 22.3: Check if search/filter is active
    final isFiltering = ref.watch(isFilterActiveProvider);
    final currentFilter = ref.watch(searchFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cases'),
        elevation: 0,
        // Phase 22.3: Remove search icon (search bar now inline)
      ),
      body: Column(
        children: [
          // Phase 22.3: Search bar
          // Phase 22 Fix: Proper reset behavior & dark mode styling
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search cases...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          // Phase 22 Fix: Clear text AND reset filter to EMPTY
                          _searchController.clear();
                          _searchDebounceTimer?.cancel();
                          ref.read(searchFilterProvider.notifier).state =
                              const SearchFilter(); // Reset to EMPTY
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (text) {
                // Phase 22 Fix: Trigger rebuild for X button visibility
                setState(() {});
                
                // Phase 22.4: Debounce search input (300ms)
                // Cancel previous timer if user is still typing
                _searchDebounceTimer?.cancel();
                
                // Phase 22 Fix: If user deletes all text, reset filter to EMPTY
                if (text.trim().isEmpty) {
                  ref.read(searchFilterProvider.notifier).state =
                      const SearchFilter(); // Reset to EMPTY, return to hierarchy
                  return;
                }
                
                // Start new timer
                _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
                  // Update provider after user stops typing
                  ref.read(searchFilterProvider.notifier).state =
                      ref.read(searchFilterProvider).copyWith(
                        query: text.trim(),
                      );
                });
              },
            ),
          ),
          
          // Phase 22.3: Filter chips
          // Phase 22 Fix: Dark mode styling
          Container(
            width: double.infinity,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade900
                : Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status filters
                  FilterChip(
                    label: const Text('Active'),
                    selected: currentFilter.status == CaseStatus.active,
                    onSelected: (selected) {
                      ref.read(searchFilterProvider.notifier).state =
                          currentFilter.copyWith(
                        status: selected ? CaseStatus.active : null,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Completed'),
                    selected: currentFilter.status == CaseStatus.completed,
                    onSelected: (selected) {
                      ref.read(searchFilterProvider.notifier).state =
                          currentFilter.copyWith(
                        status: selected ? CaseStatus.completed : null,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Archived'),
                    selected: currentFilter.status == CaseStatus.archived,
                    onSelected: (selected) {
                      ref.read(searchFilterProvider.notifier).state =
                          currentFilter.copyWith(
                        status: selected ? CaseStatus.archived : null,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Parent/Group filter
                  FilterChip(
                    label: const Text('Top-level Only'),
                    selected: currentFilter.parentCaseId == 'TOP_LEVEL',
                    onSelected: (selected) {
                      ref.read(searchFilterProvider.notifier).state =
                          currentFilter.copyWith(
                        parentCaseId: selected ? 'TOP_LEVEL' : null,
                      );
                    },
                  ),
                  // Phase 22.3: Clear filters button
                  if (isFiltering) ...[
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(searchFilterProvider.notifier).state =
                            const SearchFilter();
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: Text(
                        'Clear Filters (${ref.watch(activeFilterCountProvider)})',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Phase 22.3: Cases list
          Expanded(
            child: isFiltering
                ? _buildFilteredCasesList(ref)
                : _buildHierarchyCasesList(ref, context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOptions(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }

  /// Phase 22.3: Render filtered search results (flat list)
  Widget _buildFilteredCasesList(WidgetRef ref) {
    final casesAsync = ref.watch(filteredCasesProvider);
    
    return casesAsync.when(
      data: (cases) {
        if (cases.isEmpty) {
          // Phase 22.3: No search results
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No cases found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try different search terms or filters',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.read(searchFilterProvider.notifier).state =
                        const SearchFilter();
                  },
                  child: const Text('Clear Filters'),
                ),
              ],
            ),
          );
        }

        // Phase 22.3: Search results - flat list of regular cases
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(filteredCasesProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: cases.length,
            itemBuilder: (context, index) {
              final caseData = cases[index];
              // Phase 22.3: Simple case card (no hierarchy, no groups)
              return _CaseCard(
                caseData: caseData,
                isChild: false,
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $e', style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  /// Phase 21: Render hierarchy view with groups
  Widget _buildHierarchyCasesList(WidgetRef ref, BuildContext context) {
    final casesAsync = ref.watch(homeScreenCasesProvider);
    
    return casesAsync.when(
      data: (cases) {
        if (cases.isEmpty) {
          // Phase 21: No cases at all (original empty state)
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No cases yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a case to organize your scanned documents',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _createNewCase(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Case'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        // Phase 21: Hierarchy mode - groups with expand/collapse
        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(homeScreenCasesProvider.notifier).refresh();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _calculateTotalItems(cases),
            itemBuilder: (context, index) {
              final item = _getItemAtIndex(cases, index);
              if (item == null) return const SizedBox.shrink();
              
              if (item.viewModel.isGroup) {
                return _GroupCaseCard(
                  viewModel: item.viewModel,
                  onToggle: () {
                    ref.read(homeScreenCasesProvider.notifier)
                        .toggleGroup(item.viewModel.id);
                  },
                );
              } else {
                return _CaseCard(
                  caseData: item.viewModel.caseData,
                  isChild: item.isChild,
                );
              }
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $e', style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  /// Phase 21.4A: Calculate total items (groups + expanded children)
  int _calculateTotalItems(List<CaseViewModel> cases) {
    int count = cases.length;
    for (final caseVM in cases) {
      if (caseVM.isGroup && caseVM.isExpanded && caseVM.children != null) {
        count += caseVM.children!.length;
      }
    }
    return count;
  }

  /// Phase 21.4A: Get item at flat index (handle expanded groups)
  ({CaseViewModel viewModel, bool isChild})? _getItemAtIndex(
    List<CaseViewModel> cases,
    int index,
  ) {
    int currentIndex = 0;
    
    for (final caseVM in cases) {
      if (currentIndex == index) {
        return (viewModel: caseVM, isChild: false);
      }
      currentIndex++;
      
      if (caseVM.isGroup && caseVM.isExpanded && caseVM.children != null) {
        for (final child in caseVM.children!) {
          if (currentIndex == index) {
            return (viewModel: child, isChild: true);
          }
          currentIndex++;
        }
      }
    }
    
    return null;
  }
}

/// Phase 21.4A: Group Case Card (folder with expand/collapse)
/// Phase 21.FIX: Added delete menu entry point
class _GroupCaseCard extends ConsumerWidget {
  const _GroupCaseCard({
    required this.viewModel,
    required this.onToggle,
  });

  final CaseViewModel viewModel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.folder, color: Colors.amber),
        ),
        title: Text(
          viewModel.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${viewModel.childCount ?? 0} case(s)',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              viewModel.isExpanded 
                  ? Icons.keyboard_arrow_down 
                  : Icons.keyboard_arrow_right,
              color: Colors.grey.shade700,
            ),
            // Phase 21.FIX: Add delete menu for groups
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Group', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteGroup(context, ref, viewModel.caseData);
                }
              },
            ),
          ],
        ),
        onTap: onToggle,
      ),
    );
  }

  /// Phase 21.FIX: Delete group using existing delete flow
  Future<void> _deleteGroup(BuildContext context, WidgetRef ref, db.Case caseData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Delete "${caseData.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final database = ref.read(databaseProvider);
      
      // Phase 21.3: Use DeleteGuard for proper cascade delete
      await DeleteGuard.deleteCase(database, caseData.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Deleted "${caseData.name}"'),
            backgroundColor: Colors.orange,
          ),
        );
        await ref.read(homeScreenCasesProvider.notifier).refresh();
      }
    } catch (e) {
      // Phase 21.4E: Handle DeleteGuard exception for non-empty groups
      if (context.mounted) {
        // Check if error is about non-empty group
        final errorMessage = e.toString();
        if (errorMessage.contains('Cannot delete group') && 
            errorMessage.contains('case(s)')) {
          // Extract child count from error message
          final match = RegExp(r'contains (\d+) case\(s\)').firstMatch(errorMessage);
          final childCount = match?.group(1) ?? '?';
          
          // Show detailed dialog instead of generic snackbar
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Cannot delete group'),
                ],
              ),
              content: Text(
                'Group "${caseData.name}" contains $childCount case(s).\n\n'
                'Please move or delete child cases first.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Generic error handling
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _CaseCard extends ConsumerWidget {
  const _CaseCard({
    required this.caseData,
    this.isChild = false,
  });

  final db.Case caseData;
  final bool isChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = caseData.status == 'completed';
    final statusColor = isCompleted ? Colors.green : Colors.blue;
    final statusIcon = isCompleted ? Icons.check_circle : Icons.folder;
    final statusText = isCompleted ? 'Completed' : 'Active';
    
    // Fetch page count for this case
    final pagesAsync = ref.watch(pagesByCaseProvider(caseData.id));

    return Card(
      margin: EdgeInsets.only(
        left: isChild ? 32 : 0, // Phase 21.4A: Indent child cases
        right: 0,
        top: 6,
        bottom: 6,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          caseData.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: pagesAsync.when(
          data: (pages) => Text('${pages.length} pages · $statusText'),
          loading: () => const Text('Loading...'),
          error: (_, __) => Text(statusText),
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            // Phase 21.4D: Move to Group (only for regular cases)
            if (!caseData.isGroup)
              const PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move, size: 18),
                    SizedBox(width: 8),
                    Text('Move to Group'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _renameCase(context, ref, caseData);
            } else if (value == 'move') {
              _moveCase(context, ref, caseData);
            } else if (value == 'delete') {
              _deleteCase(context, ref, caseData);
            }
          },
        ),
        onTap: () {
          context.push('${Routes.caseDetail}/${caseData.id}');
        },
        // Phase 21.4D: Long-press to move case
        onLongPress: !caseData.isGroup ? () => _moveCase(context, ref, caseData) : null,
      ),
    );
  }

  Future<void> _renameCase(BuildContext context, WidgetRef ref, db.Case caseData) async {
    final controller = TextEditingController(text: caseData.name);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Case'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Case Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    
    final newName = controller.text.trim();
    if (newName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a case name')),
        );
      }
      return;
    }

    try {
      final database = ref.read(databaseProvider);
      await database.updateCase(
        db.CasesCompanion(
          id: drift.Value(caseData.id),
          name: drift.Value(newName),
          description: drift.Value(caseData.description),
          status: drift.Value(caseData.status),
          createdAt: drift.Value(caseData.createdAt),
          ownerUserId: drift.Value(caseData.ownerUserId),
        ),
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Renamed to: $newName'),
            backgroundColor: Colors.green,
          ),
        );
        await ref.read(homeScreenCasesProvider.notifier).refresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Phase 21.4D: Move case to different group or top-level
  Future<void> _moveCase(BuildContext context, WidgetRef ref, db.Case caseData) async {
    // Guard: Cannot move group cases
    if (caseData.isGroup) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Cannot move group cases'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final database = ref.read(databaseProvider);
      
      // Get all groups (excluding current case)
      final allCases = await database.getAllCases();
      final groups = allCases
          .where((c) => c.isGroup && c.id != caseData.id)
          .toList();

      if (!context.mounted) return;

      // Show move dialog
      final selectedParentId = await showDialog<String?>(
        context: context,
        builder: (ctx) => _MoveToGroupDialog(
          caseName: caseData.name,
          currentParentId: caseData.parentCaseId,
          availableGroups: groups,
        ),
      );

      // Phase 21.FIX: Handle dialog result properly
      // User cancelled
      if (selectedParentId == 'CANCEL' || selectedParentId == null) return;
      
      // Convert TOP_LEVEL marker to null for database API
      final targetParentId = selectedParentId == 'TOP_LEVEL' ? null : selectedParentId;
      
      // Check if actually moving to same location
      if (targetParentId == caseData.parentCaseId) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Case is already in this location'),
            ),
          );
        }
        return;
      }

      // Move case (null = top-level)
      await database.moveCaseToParent(
        caseData.id,
        targetParentId,
      );
      
      // Phase 21.FIX v5: Verify move succeeded in DB
      final movedCase = await database.getCase(caseData.id);
      print('🔄 Move result: ${caseData.name}');
      print('   Old parent: ${caseData.parentCaseId}');
      print('   New parent: ${movedCase?.parentCaseId}');
      print('   Target: $targetParentId');
      print('   Match: ${movedCase?.parentCaseId == targetParentId}');

      // Phase 21.FIX v5: Show message IMMEDIATELY before context can unmount
      final locationText = selectedParentId == 'TOP_LEVEL'
          ? 'top-level'
          : groups.firstWhere((g) => g.id == selectedParentId).name;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Moved "${caseData.name}" to $locationText'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Phase 21.FIX v5: FORCE complete provider reload
      // Invalidate triggers provider re-creation, not just refresh
      ref.invalidate(homeScreenCasesProvider);
      ref.invalidate(caseListProvider);
      ref.invalidate(caseByIdProvider(caseData.id));
      ref.invalidate(parentCaseProvider(caseData.id));
      
      print('   Providers invalidated');
      
      // Wait for providers to re-initialize from scratch
      await Future.delayed(const Duration(milliseconds: 250));
      
      print('   UI refresh complete');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error moving case: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCase(BuildContext context, WidgetRef ref, db.Case caseData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Case'),
        content: Text('Delete "${caseData.name}" and all its pages? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final database = ref.read(databaseProvider);
      
      // Phase 21.3: Use DeleteGuard for proper cascade delete
      await DeleteGuard.deleteCase(database, caseData.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Deleted "${caseData.name}"'),
            backgroundColor: Colors.orange,
          ),
        );
        await ref.read(homeScreenCasesProvider.notifier).refresh();
      }
    } catch (e) {
      // Phase 21.4E: Handle DeleteGuard exception for non-empty groups
      if (context.mounted) {
        // Check if error is about non-empty group
        final errorMessage = e.toString();
        if (errorMessage.contains('Cannot delete group') && 
            errorMessage.contains('case(s)')) {
          // Extract child count from error message
          final match = RegExp(r'contains (\d+) case\(s\)').firstMatch(errorMessage);
          final childCount = match?.group(1) ?? '?';
          
          // Show detailed dialog instead of generic snackbar
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Cannot delete group'),
                ],
              ),
              content: Text(
                'Group "${caseData.name}" contains $childCount case(s).\n\n'
                'Please move or delete child cases first.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Generic error handling
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Phase 21.4D: Move to Group Dialog
class _MoveToGroupDialog extends StatelessWidget {
  const _MoveToGroupDialog({
    required this.caseName,
    required this.currentParentId,
    required this.availableGroups,
  });

  final String caseName;
  final String? currentParentId;
  final List<db.Case> availableGroups;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.drive_file_move, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Move Case'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move "$caseName" to:',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Top-level option
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_open, color: Colors.grey),
                    ),
                    title: const Text('📂 No Group (Top-level)'),
                    trailing: currentParentId == null
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: currentParentId == null
                        ? null // Already at top-level
                        : () => Navigator.pop(context, 'TOP_LEVEL'), // Return special marker
                    enabled: currentParentId != null,
                  ),
                  const Divider(),
                  
                  // Group options
                  ...availableGroups.map((group) {
                    final isCurrentParent = group.id == currentParentId;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.folder, color: Colors.amber),
                      ),
                      title: Text('📁 ${group.name}'),
                      trailing: isCurrentParent
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: isCurrentParent
                          ? null // Already in this group
                          : () => Navigator.pop(context, group.id),
                      enabled: !isCurrentParent,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'CANCEL'),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
