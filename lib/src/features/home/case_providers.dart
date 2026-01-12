import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart' as db;

/// Singleton database provider
final databaseProvider = Provider<db.AppDatabase>((ref) {
  return db.AppDatabase();
});

/// Phase 13.1: Case list provider
final caseListProvider = FutureProvider<List<db.Case>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getAllCases();
});

/// Page list for a specific case
final pagesByCaseProvider = FutureProvider.family<List<db.Page>, String>((ref, caseId) async {
  final database = ref.watch(databaseProvider);
  final pages = await database.getPagesByCase(caseId);
  
  // Bug Fix: Filter out pages with non-existent image files (ghost pages)
  final validPages = <db.Page>[];
  for (final page in pages) {
    final file = File(page.imagePath);
    if (await file.exists()) {
      validPages.add(page);
    } else {
      print('⚠️ Skipping ghost page: ${page.id} (file not found: ${page.imagePath})');
    }
  }
  
  return validPages;
});

/// Folders for a specific case
final foldersByCaseProvider = FutureProvider.family<List<db.Folder>, String>((ref, caseId) async {
  final db = ref.watch(databaseProvider);
  return await db.getFoldersByCase(caseId);
});

/// Single case lookup
final caseByIdProvider = FutureProvider.family<db.Case?, String>((ref, caseId) async {
  final db = ref.watch(databaseProvider);
  return await db.getCase(caseId);
});

/// Phase 21.4C: Parent case lookup for breadcrumb
final parentCaseProvider = FutureProvider.family<db.Case?, String>((ref, caseId) async {
  final db = ref.watch(databaseProvider);
  return await db.getParentCase(caseId);
});
