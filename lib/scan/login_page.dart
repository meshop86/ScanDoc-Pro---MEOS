import 'package:flutter/material.dart';
import 'user_service.dart';
import 'tap_manage_page.dart';
import 'localization_service.dart';
import 'theme_service.dart';

/// LoginPage - Offline login with language & theme selection
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  late Future<String> _languageFuture;
  late Future<String> _themeFuture;
  final ValueNotifier<String?> _inlineMessage = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _languageFuture = LocalizationService.getLanguage();
    _themeFuture = ThemeService.getThemeMode();
  }

  Future<void> _login() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await _showBanner(await LocalizationService.translate('login_display_name'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await UserService.loginOffline(name);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TapManagePage()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await _showBanner('${await LocalizationService.translate('error')}: $e');
      }
    }
  }

  Future<void> _showBanner(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: Colors.blueGrey.shade50,
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLanguage(String lang) async {
    await LocalizationService.setLanguage(lang);
    if (!mounted) return;
    setState(() {
      _languageFuture = LocalizationService.getLanguage();
    });
  }

  Future<void> _changeTheme(String theme) async {
    await ThemeService.setThemeMode(theme);
    if (!mounted) return;
    setState(() {
      _themeFuture = ThemeService.getThemeMode();
    });
    final successText = await LocalizationService.translate('success');
    _inlineMessage.value = successText;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _inlineMessage.value == successText) {
        _inlineMessage.value = null;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _inlineMessage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _languageFuture,
      builder: (ctx, langSnap) {
        return FutureBuilder<String>(
          future: _themeFuture,
          builder: (ctx, themeSnap) {
            final isEnglish = langSnap.data == 'en';
            final themeMode = themeSnap.data ?? 'system';
            final accent = Theme.of(context).colorScheme.primary;

            return Scaffold(
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Welcome'),
                    SizedBox(height: 2),
                    Text(
                      'ScanDoc Pro',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.translate),
                    tooltip: isEnglish ? 'Switch to Vietnamese' : 'Chuyển English',
                    onPressed: () => _changeLanguage(isEnglish ? 'vi' : 'en'),
                  ),
                  IconButton(
                    icon: Icon(
                      themeMode == 'dark'
                          ? Icons.dark_mode
                          : themeMode == 'light'
                              ? Icons.light_mode
                              : Icons.brightness_auto,
                    ),
                    tooltip: isEnglish ? 'Theme' : 'Chủ đề',
                    onPressed: () {
                      if (themeMode == 'system') {
                        _changeTheme('light');
                      } else if (themeMode == 'light') {
                        _changeTheme('dark');
                      } else {
                        _changeTheme('system');
                      }
                    },
                  ),
                ],
              ),
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: accent.withOpacity(0.1),
                                child: Icon(Icons.description_outlined, size: 26, color: accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEnglish ? 'Welcome to ScanDoc Pro' : 'Chào mừng đến ScanDoc Pro',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isEnglish
                                          ? 'Enter your display name to continue.'
                                          : 'Nhập tên hiển thị để tiếp tục.',
                                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        TextField(
                          controller: _nameController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: isEnglish ? 'Display name' : 'Tên hiển thị',
                            hintText: isEnglish ? 'e.g., Alex Nguyen' : 'ví dụ: Alex Nguyen',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                        ),

                        const SizedBox(height: 12),
                        ValueListenableBuilder<String?>(
                          valueListenable: _inlineMessage,
                          builder: (_, message, __) {
                            if (message == null) return const SizedBox.shrink();
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                border: Border.all(color: Colors.blueGrey.shade100),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                message,
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: Icon(Icons.workspace_premium_outlined, color: accent),
                            title: Text(
                              isEnglish ? 'Upgrade to PRO (local)' : 'Nâng cấp PRO (cục bộ)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              isEnglish
                                  ? 'Encrypted local backups & Drive AppData uploads'
                                  : 'Backup mã hoá cục bộ & tải lên Drive AppData',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                          ),
                        ),

                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Text(isEnglish ? 'Continue' : 'Tiếp tục'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
