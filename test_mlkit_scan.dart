/// TEST MLKit Document Scanner
/// ⚠️ CHỈ CHẠY TRÊN THIẾT BỊ THẬT
import 'dart:io';
import 'package:flutter/material.dart';
import 'lib/src/services/scan/scan_service.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const TestMLKitApp());

class TestMLKitApp extends StatelessWidget {
  const TestMLKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MLKit Scan Test')),
        body: const TestScanPage(),
      ),
    );
  }
}

class TestScanPage extends StatefulWidget {
  const TestScanPage({super.key});

  @override
  State<TestScanPage> createState() => _TestScanPageState();
}

class _TestScanPageState extends State<TestScanPage> {
  final _scanService = ScanService();
  File? _scannedImage;
  bool _scanning = false;

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final file = await _scanService.scanDocument();
      if (file != null && mounted) {
        // Copy to app directory
        final appDir = await getApplicationDocumentsDirectory();
        final savedFile = await file.copy('${appDir.path}/scanned_${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        setState(() => _scannedImage = savedFile);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ Saved: ${savedFile.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  void dispose() {
    _scanService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _scannedImage != null
              ? Image.file(_scannedImage!, fit: BoxFit.contain)
              : const Center(child: Text('No image scanned')),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.document_scanner),
            label: Text(_scanning ? 'Scanning...' : 'Scan Document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}
