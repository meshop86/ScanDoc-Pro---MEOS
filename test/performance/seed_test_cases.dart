// Phase 22.4: Performance Test - Seed 1000 test cases
// This script creates fake cases to test search performance

import 'dart:math';
import 'package:drift/drift.dart';
import '../../lib/src/data/database/database.dart';
import '../../lib/src/domain/models.dart';

Future<void> seedTestCases(AppDatabase db, {int count = 1000}) async {
  print('🌱 Seeding $count test cases...');
  
  final random = Random();
  final startTime = DateTime.now();
  
  // Vietnamese company names for realistic test data
  final companyNames = [
    'Công ty TNHH',
    'Công ty Cổ phần',
    'Doanh nghiệp tư nhân',
    'Chi nhánh',
    'Văn phòng đại diện',
  ];
  
  final businessTypes = [
    'Thương mại',
    'Dịch vụ',
    'Sản xuất',
    'Xây dựng',
    'Vận tải',
    'Công nghệ',
    'Giáo dục',
    'Y tế',
  ];
  
  final statuses = [CaseStatus.active, CaseStatus.completed, CaseStatus.archived];
  
  // Create cases in batches for better performance
  const batchSize = 100;
  int created = 0;
  
  for (int batch = 0; batch < (count / batchSize).ceil(); batch++) {
    final casesToCreate = <CasesCompanion>[];
    final remaining = count - created;
    final currentBatchSize = remaining < batchSize ? remaining : batchSize;
    
    for (int i = 0; i < currentBatchSize; i++) {
      final caseNumber = created + i + 1;
      final companyType = companyNames[random.nextInt(companyNames.length)];
      final businessType = businessTypes[random.nextInt(businessTypes.length)];
      final status = statuses[random.nextInt(statuses.length)];
      
      // Mix of Vietnamese names with numbers for variety
      final caseName = '$companyType $businessType Số $caseNumber';
      
      // Random creation date within last 365 days
      final daysAgo = random.nextInt(365);
      final createdAt = DateTime.now().subtract(Duration(days: daysAgo));
      
      casesToCreate.add(
        CasesCompanion.insert(
          name: caseName,
          status: status.name,
          createdAt: createdAt,
          isGroup: const Value(false),
          parentCaseId: const Value(null), // All top-level for simplicity
        ),
      );
    }
    
    // Insert batch
    await db.batch((batch) {
      for (final caseData in casesToCreate) {
        batch.insert(db.cases, caseData);
      }
    });
    
    created += currentBatchSize;
    print('  ✓ Created $created / $count cases');
  }
  
  final elapsed = DateTime.now().difference(startTime);
  print('✅ Seeded $created cases in ${elapsed.inMilliseconds}ms');
  print('   Average: ${(elapsed.inMilliseconds / created).toStringAsFixed(2)}ms per case');
}

Future<void> runPerformanceTest(AppDatabase db) async {
  print('\n📊 Running Performance Tests...\n');
  
  // Test 1: Cold start - get all top-level cases
  print('Test 1: Get all cases (cold start)');
  var stopwatch = Stopwatch()..start();
  final allCases = await db.getAllCases();
  stopwatch.stop();
  print('  Result: ${allCases.length} cases in ${stopwatch.elapsedMilliseconds}ms\n');
  
  // Test 2: Search by name (single character)
  print('Test 2: Search "Công" (common prefix)');
  stopwatch = Stopwatch()..start();
  final searchResults1 = await db.searchCases('Công');
  stopwatch.stop();
  print('  Result: ${searchResults1.length} cases in ${stopwatch.elapsedMilliseconds}ms\n');
  
  // Test 3: Search by name (specific term)
  print('Test 3: Search "Thương mại" (specific)');
  stopwatch = Stopwatch()..start();
  final searchResults2 = await db.searchCases('Thương mại');
  stopwatch.stop();
  print('  Result: ${searchResults2.length} cases in ${stopwatch.elapsedMilliseconds}ms\n');
  
  // Test 4: Search with status filter
  print('Test 4: Search "Công ty" + status=active');
  stopwatch = Stopwatch()..start();
  final searchResults3 = await db.searchCases('Công ty', status: CaseStatus.active);
  stopwatch.stop();
  print('  Result: ${searchResults3.length} cases in ${stopwatch.elapsedMilliseconds}ms\n');
  
  // Test 5: Rapid typing simulation (300ms debounce)
  print('Test 5: Rapid typing simulation "Công ty TNHH" (5 queries)');
  final queries = ['C', 'Cô', 'Công', 'Công t', 'Công ty TNHH'];
  stopwatch = Stopwatch()..start();
  for (final query in queries) {
    await db.searchCases(query);
    await Future.delayed(const Duration(milliseconds: 50)); // Simulate typing speed
  }
  stopwatch.stop();
  print('  Result: 5 queries in ${stopwatch.elapsedMilliseconds}ms');
  print('  Average: ${(stopwatch.elapsedMilliseconds / queries.length).toStringAsFixed(2)}ms per query\n');
  
  // Test 6: Vietnamese diacritics
  print('Test 6: Vietnamese diacritics test');
  print('  Searching: "hoa don" (no diacritics)');
  stopwatch = Stopwatch()..start();
  final vnResults1 = await db.searchCases('hoa don');
  stopwatch.stop();
  print('  Result: ${vnResults1.length} cases in ${stopwatch.elapsedMilliseconds}ms');
  
  print('  Searching: "hoá đơn" (with diacritics)');
  stopwatch = Stopwatch()..start();
  final vnResults2 = await db.searchCases('hoá đơn');
  stopwatch.stop();
  print('  Result: ${vnResults2.length} cases in ${stopwatch.elapsedMilliseconds}ms');
  print('  Note: SQLite LIKE is case-insensitive but diacritic-sensitive\n');
  
  print('✅ Performance tests complete!\n');
}

// Usage:
// 1. Run: dart test/performance/seed_test_cases.dart
// 2. This will seed 1000 cases and run performance benchmarks
// 3. Results will be documented in Phase22_4_Polish_Report.md
void main() async {
  // Note: This is a test script. In production, you would:
  // 1. Initialize the database
  // 2. Call seedTestCases(db, count: 1000)
  // 3. Call runPerformanceTest(db)
  // 4. Clean up test data afterwards
  
  print('⚠️  This is a test script template.');
  print('    Integrate with your database setup to run actual tests.');
}
