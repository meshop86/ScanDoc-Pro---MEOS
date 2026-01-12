# Phase 21.4: UI Hierarchy Planning
**Date:** 2026-01-10  
**Status:** 📋 PLANNING (No Code Yet)  
**Prerequisites:** Phase 21.1-21.3 complete + bug fixes verified

---

## Executive Summary

**Goal:** Implement UI for case hierarchy (Group Cases + Child Cases)

**Scope:**
- ✅ Home screen: Show groups + nested cases
- ✅ Case Detail: Breadcrumb navigation
- ✅ Create flow: "Create Group" vs "Create Case"
- ✅ Move flow: Move case to group
- ✅ Delete flow: Prevent delete non-empty group

**Out of Scope:**
- ❌ Multi-level nesting (only 2 levels: Group → Child)
- ❌ Drag-and-drop (manual move only)
- ❌ Search/filter by hierarchy

---

## Current State Review

### Phase 21 Database API (Already Built)

**Available Methods:**
```dart
// Query hierarchy
Future<List<Case>> getTopLevelCases()
Future<List<Case>> getChildCases(String parentCaseId)
Future<Case?> getParentCase(String childCaseId)
Future<List<Case>> getCaseHierarchyPath(String caseId)

// Type checks
Future<bool> isGroupCase(String caseId)
Future<bool> canScanCase(String caseId)
Future<bool> canExportCase(String caseId)

// Hierarchy operations
Future<void> moveCaseToParent(String caseId, String? newParentId)
Future<int> getChildCaseCount(String parentCaseId)
```

**Delete Guard:**
```dart
// Already enforces hierarchy rules
static Future<void> deleteCase(AppDatabase db, String caseId)
static Future<bool> canDeleteGroupCase(AppDatabase db, String caseId)
```

**Constraints (MUST ENFORCE IN UI):**
1. Group Case: `isGroup = true`, `parentCaseId = null`
2. Child Case: `isGroup = false`, `parentCaseId = <group_id>`
3. Group cannot scan/export/have pages
4. Group cannot be deleted if has children

---

## UI Design Proposal

### A. Home Screen (List View)

**Current:** Flat list of all cases

**Proposed:** Grouped list with expand/collapse

#### Visual Mockup (Text):
```
┌─────────────────────────────────────────┐
│  ScanDoc Pro                      [+]    │  ← [+] opens Create menu
├─────────────────────────────────────────┤
│                                          │
│  📁 Documents                      [>]   │  ← Group Case (collapsible)
│     └─ Invoice 001            3 pages    │  ← Child Case (indented)
│     └─ Receipt 002            1 page     │
│                                          │
│  📄 Passport Scan             12 pages   │  ← Top-level Case (no parent)
│                                          │
│  📁 Projects                      [>]    │  ← Group Case (collapsed)
│                                          │
│  📄 License Plate ABC         5 pages    │  ← Top-level Case
│                                          │
└─────────────────────────────────────────┘
```

#### Layout Rules:
1. **Group Case:**
   - Icon: 📁 (folder icon)
   - No page count shown
   - Right arrow [>] for expand/collapse
   - Badge: `(3 cases)` if has children

2. **Child Case (under group):**
   - Indent left by 20px
   - Icon: 📄 (document icon)
   - Show page count
   - Swipe actions: Delete, Move

3. **Top-Level Case (no parent):**
   - No indent
   - Icon: 📄
   - Show page count
   - Swipe actions: Delete, Move to Group

#### Data Loading:
```dart
// Home Screen Provider (NEW)
final homeScreenCasesProvider = FutureProvider<List<CaseViewModel>>((ref) async {
  final db = ref.watch(databaseProvider);
  final topLevelCases = await db.getTopLevelCases();
  
  final viewModels = <CaseViewModel>[];
  
  for (final caseData in topLevelCases) {
    if (caseData.isGroup) {
      // Group Case
      final childCount = await db.getChildCaseCount(caseData.id);
      viewModels.add(CaseViewModel.group(
        case: caseData,
        childCount: childCount,
        isExpanded: false, // Default collapsed
      ));
      
      // Load children if expanded (later: state management)
      // final children = await db.getChildCases(caseData.id);
      // ...
    } else {
      // Top-level Case
      final pageCount = (await db.getPagesByCase(caseData.id)).length;
      viewModels.add(CaseViewModel.case_(
        case: caseData,
        pageCount: pageCount,
      ));
    }
  }
  
  return viewModels;
});
```

#### Interaction Flow:
1. **Tap Group Case:**
   - Expand/collapse children
   - Do NOT navigate (groups are containers only)

2. **Tap Child/Top-Level Case:**
   - Navigate to Case Detail

3. **Long Press Group:**
   - Show menu: Rename, Delete (if empty)

4. **Swipe Case:**
   - Delete
   - Move to Group (if not already in group)

---

### B. Create Case Flow

**Current:** Single "Tạo Case" button

**Proposed:** Bottom sheet with 2 options

#### Visual Mockup:
```
User taps [+] button
  ↓
┌─────────────────────────────────────────┐
│  Create New                              │
├─────────────────────────────────────────┤
│                                          │
│  📁  Create Group                        │  ← Option 1
│      Organize multiple cases             │
│                                          │
│  📄  Create Case                         │  ← Option 2
│      Scan documents                      │
│                                          │
│  [Cancel]                                │
└─────────────────────────────────────────┘
```

#### Option 1: Create Group
```
1. Show dialog: "Group Name?"
2. User enters name: "Documents"
3. Create group:
   - isGroup = true
   - parentCaseId = null
   - No scan/export
4. Return to home (group appears at top)
```

#### Option 2: Create Case
```
1. Show dialog: "Case Name?"
2. User enters name: "Invoice 001"
3. Ask: "Add to group?" (optional)
   - Show list of groups
   - Or "No group (top level)"
4. Create case:
   - isGroup = false
   - parentCaseId = <selected_group_id> or null
5. Navigate to Case Detail
```

---

### C. Case Detail Screen

**Current:** Shows case name at top

**Proposed:** Breadcrumb navigation

#### Visual Mockup:
```
┌─────────────────────────────────────────┐
│  [<] Documents > Invoice 001       [⋯]  │  ← Breadcrumb
├─────────────────────────────────────────┤
│                                          │
│  [Scan]  [Import]                        │
│                                          │
│  ┌────┐ ┌────┐ ┌────┐                   │
│  │ 1  │ │ 2  │ │ 3  │  Pages            │
│  └────┘ └────┘ └────┘                   │
│                                          │
│  [Export PDF]  [Export ZIP]              │
│                                          │
└─────────────────────────────────────────┘
```

#### Breadcrumb Behavior:
1. **If Top-Level Case:**
   - Show: `Invoice 001` (no parent)

2. **If Child Case:**
   - Show: `Documents > Invoice 001`
   - Tap "Documents" → Navigate to Group Detail (see below)

3. **Data Loading:**
```dart
// In Case Detail Screen
final hierarchyPath = await database.getCaseHierarchyPath(caseId);

if (hierarchyPath.length == 1) {
  // Top-level case
  title = hierarchyPath[0].name;
} else {
  // Child case: Group > Case
  title = '${hierarchyPath[0].name} > ${hierarchyPath[1].name}';
}
```

---

### D. Group Detail Screen (NEW)

**Purpose:** View children of a group

#### Visual Mockup:
```
┌─────────────────────────────────────────┐
│  [<] Documents                     [⋯]  │  ← Group name
├─────────────────────────────────────────┤
│                                          │
│  📁 Group: Documents                     │
│  3 cases                                 │
│                                          │
│  ─────────────────────────────────────  │
│                                          │
│  📄 Invoice 001            3 pages       │  ← Child case
│  📄 Receipt 002            1 page        │
│  📄 Contract 003           8 pages       │
│                                          │
│  [+ Add Case]                            │  ← Create child
│                                          │
└─────────────────────────────────────────┘
```

#### Features:
1. **List Children:**
   - Query: `getChildCases(groupId)`
   - Tap child → Navigate to Case Detail

2. **Add Case to Group:**
   - Tap [+ Add Case]
   - Create new case with `parentCaseId = groupId`

3. **Group Actions (Menu [⋯]):**
   - Rename Group
   - Delete Group (if empty)
   - Move to Top Level (remove parent? No - groups are always top-level)

---

### E. Move Case Flow

**Purpose:** Move case to/from group

#### Visual Mockup:
```
User long-press case → "Move to Group"
  ↓
┌─────────────────────────────────────────┐
│  Move "Invoice 001" to:                  │
├─────────────────────────────────────────┤
│                                          │
│  ○ Top Level (No Group)                 │  ← Option 1
│                                          │
│  ─────────────────────────────────────  │
│                                          │
│  ○ 📁 Documents                          │  ← Option 2
│  ○ 📁 Projects                           │
│  ○ 📁 Archive                            │
│                                          │
│  [Cancel]  [Move]                        │
└─────────────────────────────────────────┘
```

#### Implementation:
```dart
Future<void> moveCase(String caseId, String? newParentId) async {
  await database.moveCaseToParent(caseId, newParentId);
  
  // Refresh UI
  ref.invalidate(homeScreenCasesProvider);
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Case moved')),
  );
}
```

---

### F. Delete Flow with Guard

**Current:** Delete case → cascade delete all

**Proposed:** Check if group before delete

#### Flow:
```
User swipes case to delete
  ↓
Is Group Case?
  YES → Check if empty
    Empty → Delete
    Not Empty → Show error dialog:
      "Cannot delete group with cases.
       Move or delete 3 case(s) first."
  NO → Delete (cascade pages/exports)
```

#### UI Dialog:
```
┌─────────────────────────────────────────┐
│  Cannot Delete Group                     │
├─────────────────────────────────────────┤
│                                          │
│  "Documents" contains 3 case(s).         │
│                                          │
│  Please move or delete child cases       │
│  before deleting this group.             │
│                                          │
│  [OK]                                    │
└─────────────────────────────────────────┘
```

#### Implementation:
```dart
Future<void> _deleteCase(Case caseData) async {
  try {
    await DeleteGuard.deleteCase(database, caseData.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Case deleted')),
    );
  } on Exception catch (e) {
    // Show error dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cannot Delete Group'),
        content: Text(e.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

---

## UX Rules (Enforce in UI)

### Rule 1: Group Case Behavior
- ❌ Cannot scan (hide/disable Scan button)
- ❌ Cannot export (hide/disable Export buttons)
- ❌ Cannot have pages (pageCount always = 0)
- ✅ Can have child cases
- ✅ Can be renamed
- ✅ Can be deleted (if empty)

### Rule 2: Child Case Behavior
- ✅ Can scan
- ✅ Can export (if has pages)
- ✅ Can be moved to different group or top-level
- ✅ Can be deleted (cascade)

### Rule 3: Top-Level Case Behavior
- ✅ Can scan
- ✅ Can export (if has pages)
- ✅ Can be moved to group
- ✅ Can be deleted (cascade)

### Rule 4: Delete Constraints
- Group: Only if `childCount = 0`
- Case: Always allowed (cascade)

### Rule 5: Hierarchy Depth
- Max 2 levels: Group → Child
- Groups cannot be nested (no Group under Group)
- Children cannot have children

---

## State Management Plan

### Providers Needed

#### 1. Home Screen State
```dart
// View model for case list item
class CaseViewModel {
  final Case case_;
  final int? pageCount;     // For regular cases
  final int? childCount;    // For group cases
  final bool isExpanded;    // For group cases (UI state)
  
  bool get isGroup => case_.isGroup;
}

// Provider for home screen cases
final homeScreenCasesProvider = StateNotifierProvider<HomeScreenCasesNotifier, AsyncValue<List<CaseViewModel>>>(
  (ref) => HomeScreenCasesNotifier(ref.watch(databaseProvider)),
);

// Notifier to manage expand/collapse state
class HomeScreenCasesNotifier extends StateNotifier<AsyncValue<List<CaseViewModel>>> {
  HomeScreenCasesNotifier(this.database) : super(AsyncValue.loading()) {
    _load();
  }
  
  final AppDatabase database;
  
  Future<void> _load() async {
    // Load top-level cases + children
  }
  
  void toggleGroup(String groupId) {
    // Expand/collapse group
  }
}
```

#### 2. Case Detail State
```dart
// Breadcrumb path
final caseHierarchyPathProvider = FutureProvider.family<List<Case>, String>(
  (ref, caseId) async {
    final db = ref.watch(databaseProvider);
    return await db.getCaseHierarchyPath(caseId);
  },
);
```

#### 3. Group Detail State
```dart
// Children of group
final groupChildrenProvider = FutureProvider.family<List<CaseWithPageCount>, String>(
  (ref, groupId) async {
    final db = ref.watch(databaseProvider);
    final children = await db.getChildCases(groupId);
    
    final result = <CaseWithPageCount>[];
    for (final child in children) {
      final pageCount = (await db.getPagesByCase(child.id)).length;
      result.add(CaseWithPageCount(child, pageCount));
    }
    return result;
  },
);
```

---

## Implementation Roadmap

### Phase 21.4A: Home Screen (Group List)
**Scope:** Display groups + children

**Tasks:**
1. Create `CaseViewModel` class
2. Update `homeScreenCasesProvider` to load groups
3. Update `home_screen_new.dart`:
   - Group item widget (with expand/collapse)
   - Child item widget (indented)
   - Tap behavior (group vs case)
4. Test: Create group → see in list → tap to expand

**Estimate:** 2-3 hours

---

### Phase 21.4B: Create Flow
**Scope:** Create group vs create case

**Tasks:**
1. Add bottom sheet: "Create Group" vs "Create Case"
2. Create Group dialog (name only)
3. Update Create Case dialog:
   - Add "Select Group" step (optional)
   - List all groups
4. Test: Create group → create child under group

**Estimate:** 1-2 hours

---

### Phase 21.4C: Breadcrumb Navigation
**Scope:** Show hierarchy path in Case Detail

**Tasks:**
1. Add `caseHierarchyPathProvider`
2. Update Case Detail AppBar:
   - Show breadcrumb if child case
   - Tap parent → Navigate to Group Detail
3. Create Group Detail screen:
   - List children
   - Add case to group
4. Test: Child case → tap parent → see group detail

**Estimate:** 2-3 hours

---

### Phase 21.4D: Move Case Flow
**Scope:** Move case to/from group

**Tasks:**
1. Add "Move to Group" action (long press or swipe)
2. Show group selection dialog
3. Call `moveCaseToParent()`
4. Refresh home screen
5. Test: Move case to group → see in child list

**Estimate:** 1-2 hours

---

### Phase 21.4E: Delete Guard UI
**Scope:** Prevent delete non-empty group

**Tasks:**
1. Update delete action:
   - Try delete → catch exception
   - Show error dialog if group not empty
2. Test: Create group with children → try delete → see error

**Estimate:** 30 minutes

---

### Total Estimate: 7-11 hours

---

## Edge Cases to Handle

### 1. Empty Group Display
**Scenario:** Group with 0 children

**UI:**
```
📁 Empty Group                      (0 cases)
```

**Behavior:**
- Can delete immediately (no guard)
- Tapping shows empty state: "No cases in this group"

---

### 2. Long Group/Case Names
**Scenario:** Name > 40 characters

**UI:** Truncate with ellipsis
```
📁 This is a very long group n...   (3 cases)
```

---

### 3. Rapid Expand/Collapse
**Scenario:** User taps group icon rapidly

**Solution:** Debounce tap events (300ms cooldown)

---

### 4. Delete Group While Viewing Child
**Scenario:** User in Case Detail (child) → Another user deletes parent group

**Solution:**
- Case Detail still works (case not deleted)
- Breadcrumb shows "Unknown Parent > Case Name"
- Or: Detect parent deleted → update breadcrumb

---

### 5. Move Case to Same Group
**Scenario:** Case already in "Documents" → User selects "Documents" again

**Solution:**
- Disable already-selected group in dialog
- Show checkmark: `✓ Documents (Current)`

---

## Testing Checklist (UI)

### Home Screen
- [ ] Group case shows folder icon
- [ ] Group case shows child count
- [ ] Tap group expands/collapses children
- [ ] Child cases indented
- [ ] Top-level cases not indented

### Create Flow
- [ ] [+] button shows bottom sheet
- [ ] "Create Group" creates group
- [ ] "Create Case" allows group selection
- [ ] New child appears under group

### Breadcrumb
- [ ] Top-level case shows name only
- [ ] Child case shows "Group > Case"
- [ ] Tap group name navigates to Group Detail

### Group Detail
- [ ] Shows all children
- [ ] "Add Case" creates child
- [ ] Tap child navigates to Case Detail

### Move Flow
- [ ] Long press shows "Move to Group"
- [ ] Dialog lists all groups
- [ ] "Top Level" option available
- [ ] Move updates home screen

### Delete Guard
- [ ] Delete empty group succeeds
- [ ] Delete non-empty group shows error
- [ ] Error message lists child count
- [ ] Delete regular case always succeeds

---

## Design Assets Needed

### Icons
- 📁 Folder (Group Case)
- 📄 Document (Regular Case)
- ▶️ Expand arrow
- ▼ Collapse arrow
- ⋯ Menu (three dots)

### Colors
- Group case background: Light gray (#F5F5F5)
- Child case indent line: #E0E0E0
- Breadcrumb separator: #9E9E9E

---

## API Review Checklist

**Verify these methods exist and work:**

- [x] `getTopLevelCases()` - Phase 21.1
- [x] `getChildCases(String parentCaseId)` - Phase 21.1
- [x] `getCaseHierarchyPath(String caseId)` - Phase 21.1
- [x] `isGroupCase(String caseId)` - Phase 21.1
- [x] `canScanCase(String caseId)` - Phase 21.1
- [x] `canExportCase(String caseId)` - Phase 21.1
- [x] `moveCaseToParent(String caseId, String? newParentId)` - Phase 21.2
- [x] `getChildCaseCount(String parentCaseId)` - Phase 21.1
- [x] `DeleteGuard.deleteCase()` - Phase 21.3
- [x] `DeleteGuard.canDeleteGroupCase()` - Phase 21.3

**All APIs ready ✅**

---

## Open Questions

### Q1: Should groups be expandable by default?
**Options:**
- A) Collapsed by default (cleaner)
- B) Expanded by default (show all)
- C) Remember last state (persistence)

**Recommendation:** A (Collapsed) - reduces clutter

---

### Q2: Can user reorder cases within group?
**Options:**
- A) No reordering (sorted by date)
- B) Drag-and-drop reordering
- C) Manual "Move Up/Down" buttons

**Recommendation:** A (Date order) - simpler, no sortOrder field needed

---

### Q3: Quick Scan → Which group?
**Scenario:** User taps Quick Scan → Creates case immediately

**Options:**
- A) Always top-level (no parent)
- B) Ask after scan: "Add to group?"
- C) Use last-selected group (persistence)

**Recommendation:** A (Top-level) - Quick Scan should be fast, user can move later

---

### Q4: Search behavior with hierarchy?
**Scenario:** User searches "Invoice" → Multiple results in different groups

**Options:**
- A) Flat list (ignore hierarchy)
- B) Show group context: "Documents / Invoice 001"
- C) Group results by parent

**Recommendation:** B (Show context) - helps user understand location

---

## Dependencies

### Internal
- Phase 21.1-21.3 (Database + Guards) ✅
- UUID bug fix ✅
- Ghost file bug fix ✅

### External
- None (pure Flutter UI)

---

## Success Criteria

**Phase 21.4 is complete when:**

1. ✅ User can create Group Cases
2. ✅ User can create Cases under Groups
3. ✅ Home screen shows hierarchy (expandable)
4. ✅ Case Detail shows breadcrumb path
5. ✅ User can move cases to/from groups
6. ✅ Delete guard prevents deleting non-empty groups
7. ✅ UI enforces: Groups cannot scan/export
8. ✅ All UI tests pass (checklist above)

---

## Next Steps (After This Planning)

1. **Get User Approval:**
   - Review this planning doc
   - Confirm UI mockups
   - Answer open questions

2. **Start Phase 21.4A:**
   - Implement Home Screen group list
   - Create/test expand/collapse

3. **Iterate:**
   - Phase 21.4B → 21.4C → 21.4D → 21.4E
   - Test after each phase

4. **Final QA:**
   - Run full test suite (Phase21_Manual_Test_Plan.md)
   - Fix bugs
   - Polish UI

---

**Planning Status:** ✅ COMPLETE  
**Ready to Start Coding:** ⏸️ Awaiting User Approval

**Estimated Total Time:** 7-11 hours  
**Priority:** Medium (after bug fix verification)

---

**Next Action:** Review manual test results → Fix any bugs → Get approval for Phase 21.4 UI implementation

---

**Planning Document Version:** 1.0  
**Last Updated:** 2026-01-10
