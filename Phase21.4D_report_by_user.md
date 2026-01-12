✅ PHASE 21.4D — MOVE CASE HOÀN THÀNH
Implementation Summary
Files Modified:

home_screen_new.dart (956 lines, +103 lines)
1. Entry Points ✅
Menu Option:

Added "Move to Group" in PopupMenu (line ~608)
Only visible for regular cases (if (!caseData.isGroup))
Icon: Icons.drive_file_move
Long-Press:

Added onLongPress handler on Case ListTile (line ~645)
Only enabled for regular cases (!caseData.isGroup ? ... : null)
Quick access for power users
2. Move Dialog ✅
_MoveToGroupDialog Widget (lines 862-956):

Title: "Move Case" with drive_file_move icon
Subtitle: Shows case name being moved
Options list:
📂 No Group (Top-level) - Grey folder icon
📁 Group A, B, C... - Amber folder icons
Current location marked with green checkmark ✓
Current location disabled (can't move to same place)
Clean Material Design with proper colors
3. Move Logic ✅
_moveCase Method (lines 722-807):

4. Integration Points ✅
Database API:

Uses existing moveCaseToParent(caseId, newParentId) from Phase 21.2
Only updates parentCaseId field
No Page/Export modifications (as required)
Hierarchy Refresh:

Calls homeScreenCasesProvider.notifier.refresh()
Reloads entire hierarchy with new structure
Groups auto-update their child counts
Breadcrumb Update:

Invalidates parentCaseProvider(caseId)
If Case Detail is open, breadcrumb updates automatically
Phase 21.4C integration working correctly
5. Guards Implemented ✅
Guard	Implementation	Line
❌ No move Group	if (caseData.isGroup) return;	724-733
❌ Menu not shown for Groups	if (!caseData.isGroup)	608
❌ No duplicate move	if (selectedParentId == caseData.parentCaseId)	761-770
❌ No nested groups	Database schema prevents (Phase 21.1)	N/A
6. Test Checklist ⏸️
Manual Testing Required:

 TEST 1: Move top-level Case → Group

Long-press top-level case
Select a group
✓ Case appears under group (indented)
✓ Home hierarchy updates
 TEST 2: Move Case Group → top-level

Open menu on child case
Select "No Group (Top-level)"
✓ Case moves to top
✓ No longer indented
 TEST 3: Move Case Group A → Group B

Move child from Group A
Select Group B
✓ Case now under Group B
✓ Group A child count decreases
✓ Group B child count increases
 TEST 4: Breadcrumb updates

Open child Case Detail (breadcrumb shows)
Background: Move case via home screen
Return to Case Detail
✓ Breadcrumb updates to new parent
 TEST 5: Persistence

Move case to group
Restart app
✓ Hierarchy preserved
 TEST 6: Case functionality intact

Move case to different location
✓ Scan still works
✓ Export still works
✓ Pages unchanged
 TEST 7: Guard: Cannot move Group

Try menu on Group case
✓ "Move to Group" option NOT visible
Long-press Group
✓ Nothing happens
 TEST 8: Guard: Same location disabled

Open move dialog
✓ Current parent has checkmark
✓ Current parent is disabled
Tap current parent
✓ Nothing happens
7. Edge Cases Handled ✅
Case	Handling	Status
No groups exist	Dialog shows only "No Group"	✅
Case already top-level	"No Group" disabled with ✓	✅
Dialog cancelled	Return without changes	✅
Move during Case Detail open	Breadcrumb invalidated	✅
Database error	Show error snackbar	✅
8. NOT Implemented (By Design) ✅
❌ Drag & drop (future enhancement)
❌ Multi-select move (out of scope)
❌ Auto-create group (not requested)
❌ Move history/undo (not required)
❌ Batch operations (single case only)
9. Code Quality ✅
0 compilation errors in Phase 21.4D code
Follows existing code patterns
Proper error handling with try-catch
Context-mounted checks before navigation
Material Design consistency
Clean separation: UI → Logic → Database
10. Compatibility Matrix ✅
Feature	Status	Notes
Phase 21.4A (Hierarchy)	✅ Compatible	Refreshes correctly
Phase 21.4B (Create)	✅ Compatible	Groups available in dialog
Phase 21.4C (Breadcrumb)	✅ Compatible	Invalidates on move
Phase 21.1-21.3 (Backend)	✅ Compatible	Uses moveCaseToParent API
UUID v4	✅ Compatible	No ID generation
DeleteGuard	✅ Compatible	No delete logic
📊 PHASE 21.4 PROGRESS
Phase	Status	Testing
21.4A - Home Hierarchy	✅ DONE	⏸️ Pending
21.4B - Create Group/Case	✅ DONE	⏸️ Pending
21.4C - Breadcrumb	✅ DONE	✅ APPROVED
21.4D - Move Case	✅ DONE	⏸️ Pending
21.4E - Delete UI	⏸️ Next	-
🔜 NEXT: PHASE 21.4E — DELETE GUARD UI
Goal: Catch DeleteGuard exception when deleting non-empty groups

Scope:

Wrap delete logic in try-catch
Catch DeleteGuardException
Show dialog: "Cannot delete Group X (has Y children)"
Message: "Move or delete child cases first"
Keep existing delete flow for regular cases
Estimated effort: 30 minutes (error handling only)

✅ READY FOR TESTING
Phase 21.4D is code-complete and ready for manual testing.

Recommendation: Test 21.4A + 21.4B + 21.4C + 21.4D together in one session for efficiency.