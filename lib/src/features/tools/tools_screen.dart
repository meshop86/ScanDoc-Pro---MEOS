import 'package:flutter/material.dart';

/// Phase 18: Tools screen - clear "coming soon" placeholders
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Coming soon banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Advanced tools coming soon',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildToolCard(
                  context,
                  icon: Icons.edit,
                  title: 'Edit Pages',
                  subtitle: 'Crop, rotate, and adjust scanned pages',
                  enabled: false,
                ),
                const SizedBox(height: 12),
                _buildToolCard(
                  context,
                  icon: Icons.text_fields,
                  title: 'OCR Text Recognition',
                  subtitle: 'Extract text from scanned documents',
                  enabled: false,
                  badge: 'PRO',
                ),
                const SizedBox(height: 12),
                _buildToolCard(
                  context,
                  icon: Icons.auto_fix_high,
                  title: 'Auto-Enhance',
                  subtitle: 'Automatically improve document quality',
                  enabled: false,
                ),
                const SizedBox(height: 12),
                _buildToolCard(
                  context,
                  icon: Icons.cloud_upload,
                  title: 'Cloud Backup',
                  subtitle: 'Backup your cases to cloud storage',
                  enabled: false,
                  badge: 'PRO',
                ),
                const SizedBox(height: 12),
                _buildToolCard(
                  context,
                  icon: Icons.share,
                  title: 'Batch Export',
                  subtitle: 'Export multiple cases at once',
                  enabled: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool enabled = true,
    String? badge,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: enabled ? Theme.of(context).colorScheme.primary : Colors.grey,
          size: 32,
        ),
        title: Row(
          children: [
            Text(title),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        trailing: enabled ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
        enabled: enabled,
        onTap: enabled
            ? () {
                // TODO: Navigate to tool
              }
            : null,
      ),
    );
  }
}
