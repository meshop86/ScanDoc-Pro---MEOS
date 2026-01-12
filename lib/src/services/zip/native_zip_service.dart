import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeZipService {
  NativeZipService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.bienso.zip/native');

  final MethodChannel _channel;

  Future<String> zipFolder({required String sourcePath, required String outputPath}) async {
    try {
      final result = await _channel.invokeMethod<String>('zipFolder', {
        'sourcePath': sourcePath,
        'outputPath': outputPath,
      });

      if (result == null) {
        throw Exception('ZIP operation returned null');
      }

      return result;
    } on PlatformException catch (e) {
      debugPrint('Platform error during ZIP: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error during ZIP: $e');
      rethrow;
    }
  }
}
