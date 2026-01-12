import 'package:scandocpro/src/data/database/database.dart' as db;
import 'package:scandocpro/src/domain/models.dart' show CaseStatus;

/// Phase 23.2: Fake database for provider testing
/// 
/// Mimics AppDatabase behavior without real database or in-memory instance.
/// Allows controlled test data and verification of method calls.
class FakeAppDatabase extends db.AppDatabase {
  // Test data storage
  final List<db.Case> _topLevelCases = [];
  final List<db.Case> _searchResults = [];
  
  // Tracking
  int getTopLevelCasesCalls = 0;
  int searchCasesCalls = 0;
  String? lastSearchQuery;
  CaseStatus? lastSearchStatus;
  String? lastSearchParent;
  
  // Constructor (doesn't call super - pure fake)
  FakeAppDatabase._();
  
  factory FakeAppDatabase() => FakeAppDatabase._();
  
  /// Set test data for getTopLevelCases()
  void setTopLevelCases(List<db.Case> cases) {
    _topLevelCases.clear();
    _topLevelCases.addAll(cases);
  }
  
  /// Set test data for searchCases()
  void setSearchResults(List<db.Case> cases) {
    _searchResults.clear();
    _searchResults.addAll(cases);
  }
  
  @override
  Future<List<db.Case>> getTopLevelCases() async {
    getTopLevelCasesCalls++;
    return List.from(_topLevelCases); // Return copy
  }
  
  @override
  Future<List<db.Case>> searchCases(
    String? query, {
    CaseStatus? status,
    String? parentCaseId,
  }) async {
    searchCasesCalls++;
    lastSearchQuery = query;
    lastSearchStatus = status;
    lastSearchParent = parentCaseId;
    return List.from(_searchResults); // Return copy
  }
  
  /// Reset tracking
  void resetTracking() {
    getTopLevelCasesCalls = 0;
    searchCasesCalls = 0;
    lastSearchQuery = null;
    lastSearchStatus = null;
    lastSearchParent = null;
  }
}
