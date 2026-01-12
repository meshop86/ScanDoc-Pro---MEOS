import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'tap_status.dart';

class UserInfo {
  final String userId;
  final String displayName;

  const UserInfo({required this.userId, required this.displayName});

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
      };

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        userId: json['user_id']?.toString() ?? 'unknown_user',
        displayName: json['display_name']?.toString() ?? 'Unknown',
      );
}

class ManifestService {
  static const _hosoRoot = 'HoSoXe';
  static const _manifestFile = 'manifest.json';
  static const _userInfoFile = 'user_info.json';
  static const _manifestVersion = '1.1';

  // Doc type required map
  static const Map<String, bool> _docRequired = {
    'to_khai': true,
    'nguon_goc': true,
    'custom_1': false,
    'custom_2': false,
  };

  /// Lưu user info vào documents/user_info.json
  static Future<void> saveUserInfo(UserInfo info) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$_userInfoFile');
    await file.writeAsString(jsonEncode(info.toJson()));
  }

  /// Load user info, fallback defaultInfo nếu chưa có
  static Future<UserInfo> loadUserInfo({UserInfo? defaultInfo}) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$_userInfoFile');
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        return UserInfo.fromJson(data);
      } catch (_) {
        // ignore parse error, fallback
      }
    }
    return defaultInfo ?? const UserInfo(userId: 'unknown_user', displayName: 'Unknown');
  }

  /// Build manifest.json and save inside HoSoXe/<tapCode>/<bienSo>/manifest.json
  static Future<File> writeManifest({
    required String bienSo,
    required UserInfo userInfo,
    String? tapCode,
    Map<String, String>? userLabels,
    Map<String, String>? systemLabels,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    
    final String folderPath;
    if (tapCode != null) {
      folderPath = '${docsDir.path}/$_hosoRoot/$tapCode/$bienSo';
    } else {
      folderPath = '${docsDir.path}/$_hosoRoot/$bienSo';
    }
    
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      throw Exception('Thư mục hồ sơ không tồn tại');
    }

    // List all jpg files
    final files = folder
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.jpg'))
      .toList();

    // Group by docType based on naming: <docType>_<bienSo>_p<n>.jpg
    final Map<String, List<_PageEntry>> grouped = {};
    // Match pattern: <docType>_<bienSo>_p<n>.jpg (n is 1..)
    final regex = RegExp('^(.*?)_${RegExp.escape(bienSo)}_p(\\d+)\\.jpg\$');
    for (final file in files) {
      final name = file.path.split('/').last;
      final match = regex.firstMatch(name);
      if (match == null) continue;
      final docType = match.group(1) ?? '';
      final pageNum = int.tryParse(match.group(2) ?? '') ?? 0;
      grouped.putIfAbsent(docType, () => []);
      grouped[docType]!.add(_PageEntry(name: name, page: pageNum));
    }

    // Build documents list sorted
    final documents = grouped.entries.map((entry) {
      final pages = entry.value..sort((a, b) => a.page.compareTo(b.page));
      return {
        'type': entry.key,
        'required': _docRequired[entry.key] ?? false,
        'pages': pages.map((p) => p.name).toList(),
      };
    }).toList();

    final existing = await readManifestFile(File('${folder.path}/$_manifestFile'));
    final existingUserLabels = existing['labels'] is Map && existing['labels']['user'] is Map
        ? Map<String, String>.from(existing['labels']['user'] as Map)
        : <String, String>{};
    final existingSystemLabels = existing['labels'] is Map && existing['labels']['system'] is Map
        ? Map<String, String>.from(existing['labels']['system'] as Map)
        : <String, String>{};

    final now = DateTime.now();
    final manifest = {
      'manifestVersion': _manifestVersion,
      // Legacy fields (backward compatibility)
      'bien_so': bienSo,
      // New generalized fields (Phase 9)
      'case_name': bienSo,  // Default to bien_so; can be overridden via tap_manifest
      'document_set_display_name': bienSo,  // Will store user-friendly name
      'document_set_slug': bienSo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
      'created_at': now.toIso8601String(),
      'created_by': userInfo.toJson(),
      'device': {
        'platform': 'iOS',
        'model': 'iPhone',
        'os_version': Platform.operatingSystemVersion,
      },
      'documents': documents,
      'labels': {
        'system': {
          'tap_code': tapCode ?? 'standalone',
          'bien_so': bienSo,
          ...existingSystemLabels,
          if (systemLabels != null) ...systemLabels,
        },
        'user': {
          ...existingUserLabels,
          if (userLabels != null) ...userLabels,
        },
      },
    };

    final manifestFile = File('${folder.path}/$_manifestFile');
    await manifestFile.writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
    return manifestFile;
  }

  /// Build tap_manifest.json for entire TAP (multiple bien_so)
  /// Save to: HoSoXe/<tapCode>/tap_manifest.json
  static Future<File> writeTapManifest({
    required String tapCode,
    required UserInfo userInfo,
    TapStatus tapStatus = TapStatus.open,
    Map<String, String>? userLabels,
    Map<String, String>? systemLabels,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tapFolder = Directory('${docsDir.path}/$_hosoRoot/$tapCode');
    if (!await tapFolder.exists()) {
      throw Exception('Thư mục TAP không tồn tại');
    }

    final existing = await readManifestFile(File('${tapFolder.path}/tap_manifest.json'));
    final existingUserLabels = existing['labels'] is Map && existing['labels']['user'] is Map
        ? Map<String, String>.from(existing['labels']['user'] as Map)
        : <String, String>{};
    final existingSystemLabels = existing['labels'] is Map && existing['labels']['system'] is Map
        ? Map<String, String>.from(existing['labels']['system'] as Map)
        : <String, String>{};

    // List all bo_ho_so folders (biển số)
    final boHoSoList = tapFolder
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path.split('/').last)
        .where((name) => !name.startsWith('.'))
        .toList();

    // Build bo_ho_so array
    final boHoSoArray = boHoSoList.map((bienSo) => {
      'bien_so': bienSo,
      'folder': bienSo,
    }).toList();

    final now = DateTime.now();
    final tapManifest = {
      'manifestVersion': _manifestVersion,
      'tap_code': tapCode,
      'created_at': now.toIso8601String(),
      'created_by': userInfo.toJson(),
      'tap_status': tapStatus.value,
      'bo_ho_so': boHoSoArray,
      'labels': {
        'system': {
          'tap_code': tapCode,
          'state': tapStatus.value,
          ...existingSystemLabels,
          if (systemLabels != null) ...systemLabels,
        },
        'user': {
          ...existingUserLabels,
          if (userLabels != null) ...userLabels,
        },
      },
    };

    final tapManifestFile = File('${tapFolder.path}/tap_manifest.json');
    await tapManifestFile.writeAsString(const JsonEncoder.withIndent('  ').convert(tapManifest));
    print('✓ tap_manifest.json created for $tapCode');
    return tapManifestFile;
  }

  /// Read manifest JSON safely, return empty map on failure
  static Future<Map<String, dynamic>> readManifestFile(File file) async {
    try {
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return {};
  }

  static Future<Map<String, String>> readTapUserLabels(String tapCode) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/$_hosoRoot/$tapCode/tap_manifest.json');
    final data = await readManifestFile(file);
    if (data['labels'] is Map && data['labels']['user'] is Map) {
      return Map<String, String>.from(data['labels']['user'] as Map);
    }
    return {};
  }

  static Future<Map<String, String>> readDocumentUserLabels(String bienSo, {String? tapCode}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final filePath = tapCode != null
        ? '${docsDir.path}/$_hosoRoot/$tapCode/$bienSo/$_manifestFile'
        : '${docsDir.path}/$_hosoRoot/$bienSo/$_manifestFile';
    final file = File(filePath);
    final data = await readManifestFile(file);
    if (data['labels'] is Map && data['labels']['user'] is Map) {
      return Map<String, String>.from(data['labels']['user'] as Map);
    }
    return {};
  }
}

class _PageEntry {
  final String name;
  final int page;
  _PageEntry({required this.name, required this.page});
}
