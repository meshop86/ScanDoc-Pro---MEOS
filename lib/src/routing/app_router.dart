import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/case/case_detail_screen.dart';
import '../features/files/files_screen.dart';
import '../features/home/home_screen_new.dart';
import '../features/home/case_providers.dart';
import '../features/me/me_screen.dart';
import '../features/navigation/main_navigation.dart';
import '../features/scan/quick_scan_screen.dart';
import '../features/tools/tools_screen.dart';
import '../routing/routes.dart';
import '../services/migration/migration_service.dart';

/// Phase 13.1: Updated GoRouter with StatefulShellRoute for bottom navigation persistence
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      final loggedIn = authState.isAuthenticated;
      final loggingIn = state.matchedLocation == Routes.login;
      
      // Redirect unauthenticated users to login
      if (!loggedIn && !loggingIn) return Routes.login;
      
      // Redirect authenticated users away from login
      if (loggedIn && loggingIn) return Routes.home;
      
      return null;
    },
    routes: [
      // Login route (not wrapped in shell)
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Main navigation shell with bottom tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigation(child: navigationShell);
        },
        branches: [
          // Home branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          
          // Files branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.files,
                builder: (context, state) => const FilesScreen(),
              ),
            ],
          ),
          
          // Scan branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.scan,
                builder: (context, state) => const QuickScanScreen(),
              ),
            ],
          ),
          
          // Tools branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tools,
                builder: (context, state) => const ToolsScreen(),
              ),
            ],
          ),
          
          // Me branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.me,
                builder: (context, state) => const MeScreen(),
              ),
            ],
          ),
        ],
      ),
      
      // Case detail (new)
      GoRoute(
        path: '${Routes.caseDetail}/:caseId',
        builder: (context, state) {
          final caseId = state.pathParameters['caseId'];
          if (caseId == null) {
            return const Scaffold(body: Center(child: Text('Missing case id')));
          }
          return CaseDetailScreen(caseId: caseId);
        },
      ),
    ],
  );
});

/// Migration trigger on app init (runs once)
final migrationProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(databaseProvider);
  final migrationService = MigrationService(db);
  return await migrationService.runMigrationIfNeeded();
});

