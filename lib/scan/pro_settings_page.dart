import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'backup_service.dart';
import 'pro_entitlement_service.dart';
import 'google_drive_service.dart';

class ProSettingsPage extends StatefulWidget {
  const ProSettingsPage({super.key});

  @override
  State<ProSettingsPage> createState() => _ProSettingsPageState();
}

class _ProSettingsPageState extends State<ProSettingsPage> {
  bool _proActive = false;
  bool _isLoading = false;
  bool _isBackingUp = false;
  GoogleSignInAccount? _account;
  String? _lastBackupId;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    final pro = await ProEntitlementService.isProActive();
    final acct = await GoogleDriveService.currentUser();
    setState(() {
      _proActive = pro;
      _account = acct;
      _isLoading = false;
    });
  }

  Future<void> _togglePro(bool value) async {
    setState(() => _isLoading = true);
    if (value) {
      await ProEntitlementService.activate();
    } else {
      await ProEntitlementService.deactivate();
    }
    await _loadState();
  }

  Future<void> _connectGoogle() async {
    setState(() => _isLoading = true);
    try {
      final acct = await GoogleDriveService.signIn();
      setState(() => _account = acct);
    } catch (e) {
      _showSnack('Google sign-in failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnectGoogle() async {
    setState(() => _isLoading = true);
    await GoogleDriveService.signOut();
    setState(() {
      _account = null;
      _isLoading = false;
    });
  }

  Future<void> _backupNow() async {
    if (!_proActive) {
      _showSnack('PRO required for backup');
      return;
    }
    if (_account == null) {
      _showSnack('Please connect Google (Drive AppData)');
      return;
    }
    setState(() => _isBackingUp = true);
    try {
      final id = await BackupService.backupNow(account: _account!);
      setState(() => _lastBackupId = id);
      _showSnack('Backup uploaded (id: ${id.isEmpty ? 'unknown' : id})');
    } catch (e) {
      _showSnack('Backup failed: $e');
    } finally {
      setState(() => _isBackingUp = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PRO & Backup'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('PRO Tier'),
                    subtitle: Text(_proActive ? 'Active' : 'Inactive'),
                    value: _proActive,
                    onChanged: (v) => _togglePro(v),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Google Drive (AppData)'),
                    subtitle: Text(_account?.email ?? 'Not connected'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_account != null)
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: _isLoading ? null : _disconnectGoogle,
                          ),
                        IconButton(
                          icon: const Icon(Icons.login),
                          onPressed: _isLoading ? null : _connectGoogle,
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Backup now'),
                    subtitle: const Text('Encrypt and upload to Drive AppData (PRO only)'),
                    trailing: _isBackingUp
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.cloud_upload),
                            onPressed: _isBackingUp ? null : _backupNow,
                          ),
                  ),
                ),
                if (_lastBackupId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Last backup id: $_lastBackupId'),
                  ),
                Card(
                  child: ListTile(
                    title: const Text('Restore (coming soon)'),
                    subtitle: const Text('Visible but disabled by requirement'),
                    trailing: IconButton(
                      icon: const Icon(Icons.cloud_download),
                      onPressed: null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
