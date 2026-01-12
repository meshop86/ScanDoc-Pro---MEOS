import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Phase 16: Image Persistence Service
/// 
/// Copies scanned images from VisionKit temp storage to app-owned persistent storage.
/// Prevents image loss when iOS cleans temp files.
class ImageStorageService {
  /// Get the persistent storage directory for scanned images
  /// Location: /ApplicationDocuments/ScanDocPro/images/
  static Future<Directory> getImagesDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDocDir.path}/ScanDocPro/images');
    
    // Create directory if it doesn't exist
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
      print('✓ Created images directory: ${imagesDir.path}');
    }
    
    return imagesDir;
  }

  /// Copy image from temp path to persistent storage
  /// 
  /// Returns the new persistent path, or null if copy failed
  static Future<String?> copyImageToPersistentStorage(String tempPath) async {
    try {
      final tempFile = File(tempPath);
      
      // Check if temp file exists
      if (!await tempFile.exists()) {
        print('⚠️ Temp file not found: $tempPath');
        return null;
      }

      // Generate unique filename using timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(tempPath);
      final filename = 'scan_${timestamp}_${path.basename(tempPath)}';
      
      // Get persistent directory
      final imagesDir = await getImagesDirectory();
      final persistentPath = '${imagesDir.path}/$filename';
      
      // Copy file
      await tempFile.copy(persistentPath);
      print('✓ Copied image: $filename');
      
      return persistentPath;
    } catch (e) {
      print('❌ Error copying image from $tempPath: $e');
      return null;
    }
  }

  /// Copy multiple images from temp paths to persistent storage
  /// 
  /// Returns a map of original temp paths to new persistent paths
  /// Skips images that fail to copy (returns null for those)
  static Future<Map<String, String?>> copyImagesToPersistentStorage(
    List<String> tempPaths,
  ) async {
    final results = <String, String?>{};
    
    for (final tempPath in tempPaths) {
      final persistentPath = await copyImageToPersistentStorage(tempPath);
      results[tempPath] = persistentPath;
    }
    
    return results;
  }

  /// Delete image file from persistent storage
  /// 
  /// Called when a Page is deleted from the database
  /// Returns true if deleted, false if file didn't exist or error occurred
  static Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      
      if (!await file.exists()) {
        print('ℹ️ Image already deleted or not found: $imagePath');
        return false;
      }
      
      await file.delete();
      print('✓ Deleted image: ${path.basename(imagePath)}');
      return true;
    } catch (e) {
      print('❌ Error deleting image $imagePath: $e');
      return false;
    }
  }

  /// Clean up orphaned images (images not referenced by any Page)
  /// 
  /// This is a maintenance operation that can be run periodically
  /// Returns the number of orphaned images deleted
  static Future<int> cleanupOrphanedImages(List<String> activeImagePaths) async {
    try {
      final imagesDir = await getImagesDirectory();
      
      if (!await imagesDir.exists()) {
        return 0;
      }
      
      final allFiles = imagesDir.listSync();
      int deletedCount = 0;
      
      for (final file in allFiles) {
        if (file is File) {
          final filePath = file.path;
          
          // If this image is not in the active list, it's orphaned
          if (!activeImagePaths.contains(filePath)) {
            await file.delete();
            print('🗑️ Deleted orphaned image: ${path.basename(filePath)}');
            deletedCount++;
          }
        }
      }
      
      return deletedCount;
    } catch (e) {
      print('❌ Error cleaning up orphaned images: $e');
      return 0;
    }
  }

  /// Get the size of all stored images in bytes
  static Future<int> getTotalStorageSize() async {
    try {
      final imagesDir = await getImagesDirectory();
      
      if (!await imagesDir.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      final allFiles = imagesDir.listSync(recursive: true);
      
      for (final file in allFiles) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      print('❌ Error calculating storage size: $e');
      return 0;
    }
  }

  /// Check if a path is a temp path (VisionKit temp directory)
  static bool isTempPath(String path) {
    return path.contains('/tmp/') || 
           path.contains('/var/folders/') ||
           path.contains('NSTemporaryDirectory');
  }

  /// Check if a path is in our persistent storage
  static Future<bool> isPersistentPath(String path) async {
    final imagesDir = await getImagesDirectory();
    return path.startsWith(imagesDir.path);
  }
}
