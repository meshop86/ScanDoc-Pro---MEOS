import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum CaseStatus { active, completed, archived }

enum PageStatus { captured, processing, ready }

enum UserRole { admin, user }

// ============================================================================
// NEW PHASE 13 MODELS - Professional Document Scanner
// ============================================================================

/// User account for the app
class UserAccount {
  UserAccount({
    String? id,
    required this.username,
    required this.displayName,
    required this.role,
    this.signaturePath,
  }) : id = id ?? _uuid.v4();

  final String id;
  final String username;
  final String displayName;
  final UserRole role;
  final String? signaturePath;
}

/// A Page represents a scanned document page
class Page {
  Page({
    String? id,
    required this.caseId,
    this.folderId,
    required this.name,
    required this.imagePath,
    this.thumbnailPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.pageNumber,
    this.status = PageStatus.ready,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String caseId;
  final String? folderId; // Optional: pages can be in folders or directly in case
  String name;
  final String imagePath;
  final String? thumbnailPath;
  DateTime createdAt;
  DateTime updatedAt;
  int? pageNumber;
  PageStatus status;
}

/// Optional folder organization within a Case
class Folder {
  Folder({
    String? id,
    required this.caseId,
    required this.name,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Page>? pages,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        pages = pages ?? [];

  final String id;
  final String caseId;
  String name;
  String? description;
  DateTime createdAt;
  DateTime updatedAt;
  final List<Page> pages;

  int get pageCount => pages.length;
}

/// A Case is the top-level container for documents
class Case {
  Case({
    String? id,
    required this.name,
    this.description,
    this.status = CaseStatus.active,
    DateTime? createdAt,
    this.completedAt,
    required this.ownerUserId,
    List<Folder>? folders,
    List<Page>? pages,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        folders = folders ?? [],
        pages = pages ?? [];

  final String id;
  String name;
  String? description;
  CaseStatus status;
  DateTime createdAt;
  DateTime? completedAt;
  final String ownerUserId;
  final List<Folder> folders;
  final List<Page> pages; // Pages not in any folder

  int get totalPageCount => pages.length + folders.fold(0, (sum, f) => sum + f.pageCount);
  bool get hasPages => totalPageCount > 0;
  bool get isCompleted => status == CaseStatus.completed;
}

// ============================================================================
// LEGACY MODELS - Kept for backward compatibility during migration
// ============================================================================

@Deprecated('Use Page instead. Will be removed after migration.')
enum DocStatus { missing, captured }

@Deprecated('Use Case instead. TapHoSo will be migrated to Case.')
enum TapStatus { inProgress, completed }

@Deprecated('Use Page instead. GiayTo represents old document model.')
class GiayTo {
  GiayTo({
    String? id,
    required this.boId,
    required this.name,
    this.requiredDoc = false,
    this.imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String boId;
  String name;
  bool requiredDoc;
  String? imagePath;
  DateTime createdAt;
  DateTime updatedAt;

  DocStatus get status => imagePath == null ? DocStatus.missing : DocStatus.captured;
}

@Deprecated('Use Folder instead. BoHoSo will be migrated to Folder.')
class BoHoSo {
  BoHoSo({
    String? id,
    required this.tapId,
    required this.licensePlate,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<GiayTo>? documents,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        documents = documents ?? [];

  final String id;
  final String tapId;
  String licensePlate;
  DateTime createdAt;
  DateTime updatedAt;
  final List<GiayTo> documents;

  bool get isComplete => documents.every((doc) => doc.status == DocStatus.captured || !doc.requiredDoc);
}

@Deprecated('Use Case instead. TapHoSo will be migrated to Case.')
class TapHoSo {
  TapHoSo({
    String? id,
    required this.code,
    this.status = TapStatus.inProgress,
    DateTime? createdAt,
    this.completedAt,
    required this.ownerUserId,
    List<BoHoSo>? boList,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        boList = boList ?? [];

  final String id;
  final String code;
  TapStatus status;
  DateTime createdAt;
  DateTime? completedAt;
  final String ownerUserId;
  final List<BoHoSo> boList;

  bool get hasMissingDocs => boList.any((bo) => !bo.isComplete);
}
