import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Phase 20: Export Service for PDF and ZIP generation
/// 
/// Responsibilities:
/// - Generate PDF from page images
/// - Generate ZIP from page images
/// - Save exports to app-owned storage
/// - Return file path for database recording
class ExportService {

  /// Get the exports directory in app storage
  /// Location: /ApplicationDocuments/ScanDocPro/exports/
  static Future<Directory> _getExportsDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(appDocDir.path, 'ScanDocPro', 'exports'));
    
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
      print('📁 Created exports directory: ${exportsDir.path}');
    }
    
    return exportsDir;
  }

  /// Export pages as PDF
  /// 
  /// Returns file path on success, null on failure
  /// 
  /// Parameters:
  /// - caseName: Name for the PDF file (e.g., "Case 001")
  /// - imagePaths: List of image file paths to include
  /// 
  /// Output: /exports/Case_001_<timestamp>.pdf
  static Future<String?> exportPDF({
    required String caseName,
    required List<String> imagePaths,
  }) async {
    try {
      if (imagePaths.isEmpty) {
        print('⚠️ Export PDF: No images provided');
        return null;
      }

      print('📄 Exporting PDF: $caseName (${imagePaths.length} pages)');

      // Create PDF document
      final pdf = pw.Document();

      // Add each image as a page
      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        final imageFile = File(imagePath);

        if (!await imageFile.exists()) {
          print('⚠️ Image not found, skipping: $imagePath');
          continue;
        }

        try {
          final imageBytes = await imageFile.readAsBytes();
          final image = pw.MemoryImage(imageBytes);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                );
              },
            ),
          );

          print('  ✓ Added page ${i + 1}/${imagePaths.length}');
        } catch (e) {
          print('  ⚠️ Failed to add page ${i + 1}: $e');
          // Continue with other pages
        }
      }

      if (pdf.document.pdfPageList.pages.isEmpty) {
        print('❌ Export PDF failed: No valid pages');
        return null;
      }

      // Generate filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = caseName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = '${sanitizedName}_$timestamp.pdf';

      // Save to exports directory
      final exportsDir = await _getExportsDirectory();
      final filePath = p.join(exportsDir.path, fileName);
      final file = File(filePath);

      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      print('✓ PDF exported: $fileName (${(pdfBytes.length / 1024).toStringAsFixed(1)} KB)');
      return filePath;
    } catch (e) {
      print('❌ Export PDF error: $e');
      return null;
    }
  }

  /// Export pages as ZIP archive
  /// 
  /// Returns file path on success, null on failure
  /// 
  /// Parameters:
  /// - caseName: Name for the ZIP file (e.g., "Case 001")
  /// - imagePaths: List of image file paths to include
  /// 
  /// Output: /exports/Case_001_<timestamp>.zip
  static Future<String?> exportZIP({
    required String caseName,
    required List<String> imagePaths,
  }) async {
    try {
      if (imagePaths.isEmpty) {
        print('⚠️ Export ZIP: No images provided');
        return null;
      }

      print('📦 Exporting ZIP: $caseName (${imagePaths.length} files)');

      // Create archive
      final archive = Archive();

      // Add each image to archive
      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        final imageFile = File(imagePath);

        if (!await imageFile.exists()) {
          print('⚠️ Image not found, skipping: $imagePath');
          continue;
        }

        try {
          final imageBytes = await imageFile.readAsBytes();
          final fileName = 'page_${i + 1}${p.extension(imagePath)}';

          archive.addFile(ArchiveFile(
            fileName,
            imageBytes.length,
            imageBytes,
          ));

          print('  ✓ Added file ${i + 1}/${imagePaths.length}: $fileName');
        } catch (e) {
          print('  ⚠️ Failed to add file ${i + 1}: $e');
          // Continue with other files
        }
      }

      if (archive.files.isEmpty) {
        print('❌ Export ZIP failed: No valid files');
        return null;
      }

      // Encode archive
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        print('❌ Export ZIP failed: Encoding error');
        return null;
      }

      // Generate filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = caseName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = '${sanitizedName}_$timestamp.zip';

      // Save to exports directory
      final exportsDir = await _getExportsDirectory();
      final filePath = p.join(exportsDir.path, fileName);
      final file = File(filePath);

      await file.writeAsBytes(zipBytes);

      print('✓ ZIP exported: $fileName (${(zipBytes.length / 1024).toStringAsFixed(1)} KB)');
      return filePath;
    } catch (e) {
      print('❌ Export ZIP error: $e');
      return null;
    }
  }

  /// Get file size in bytes
  static Future<int?> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      print('⚠️ Failed to get file size: $e');
      return null;
    }
  }

  /// Delete export file from disk
  /// Returns true if deleted, false if not found or error
  static Future<bool> deleteExportFile(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        print('ℹ️ Export file already deleted or not found: $filePath');
        return false;
      }
      
      await file.delete();
      print('✓ Deleted export file: ${p.basename(filePath)}');
      return true;
    } catch (e) {
      print('❌ Error deleting export file $filePath: $e');
      return false;
    }
  }

  /// Format file size for display
  static String formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown';
    
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
