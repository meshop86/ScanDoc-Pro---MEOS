import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/routing/app_router.dart';
import 'src/data/database/database.dart';
import 'src/services/migration/migration_service.dart';

/// Phase 13+ Main Entry Point - Riverpod + GoRouter Architecture
/// NO legacy scan module, NO vehicle terminology
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger migration on startup (runs once)
    ref.watch(migrationProvider);
    
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'ScanDoc Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
