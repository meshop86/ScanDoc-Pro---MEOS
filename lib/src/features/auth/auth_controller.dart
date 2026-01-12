import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';

class AuthState {
  const AuthState({this.user});

  final UserAccount? user;

  bool get isAuthenticated => user != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState());

  final Ref _ref;

  void login({required String username}) {
    // Simplified local auth: one user object; admin hidden elsewhere.
    final user = UserAccount(
      username: username,
      displayName: username,
      role: UserRole.user,
    );
    state = AuthState(user: user);
  }

  void logout() {
    state = const AuthState();
    // Invalidate tap list to clear old user's data
    _ref.invalidate(tapListProviderFamily);
  }
}

// Forward declaration to avoid circular dependency
final tapListProviderFamily = Provider.family<void, String>((ref, userId) {});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
