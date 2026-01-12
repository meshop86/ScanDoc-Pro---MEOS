import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class ZipService {
  ZipService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('zip_channel');

  final MethodChannel _channel;

  Future<File> zipTap({required String tapPath, required String zipName}) async {
    final outputPath = p.join(tapPath, '$zipName.zip');
    final result = await _channel.invokeMethod<String>('zipFolder', <String, dynamic>{
      'sourcePath': tapPath,
      'zipPath': outputPath,
    });
    if (result == null) {
      throw Exception('ZIP failed');
    }
    return File(result);
  }
}
