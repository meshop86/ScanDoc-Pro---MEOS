import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

/// ThemeService – manages Light/Dark theme preference
/// Supports system default or manual override
class ThemeService {
  static const String _prefFile = 'theme_pref.json';
  static const String _systemDefault = 'system';
  static const String _light = 'light';
  static const String _dark = 'dark';

  /// Get stored theme preference
  static Future<String> getThemeMode() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/$_prefFile');
      if (!await file.exists()) return _systemDefault;
      
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data['theme']?.toString() ?? _systemDefault;
    } catch (_) {
      return _systemDefault;
    }
  }

  /// Save theme preference
  static Future<void> setThemeMode(String mode) async {
    if (mode != _systemDefault && mode != _light && mode != _dark) {
      throw ArgumentError('Invalid theme mode: $mode');
    }
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$_prefFile');
    await file.writeAsString(jsonEncode({'theme': mode}));
  }

  /// Convert stored preference to Flutter ThemeMode
  static Future<ThemeMode> getFlutterThemeMode() async {
    final mode = await getThemeMode();
    switch (mode) {
      case _light:
        return ThemeMode.light;
      case _dark:
        return ThemeMode.dark;
      case _systemDefault:
      default:
        return ThemeMode.system;
    }
  }

  /// Get light theme data
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1F77BC),  // Professional blue
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        elevation: 2,
        centerTitle: true,
        backgroundColor: const Color(0xFF1F77BC),
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1F77BC),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Get dark theme data
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF64B5F6),  // Lighter blue for dark
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        elevation: 2,
        centerTitle: true,
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF64B5F6),
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Common icon colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFF44336);
  static const Color warningOrange = Color(0xFFFFC107);
  static const Color infoBlue = Color(0xFF2196F3);
}
