import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/logger.dart';
import '../data/repositories/local_auth_repository.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/auth_repository.dart';

enum AuthStatus { unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final UserProfile? profile;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.profile,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Bu provider'ı override ederek (örn. testlerde veya gerçek backend'e
/// geçişte) [LocalAuthRepository] yerine başka bir implementasyon
/// bağlayabilirsiniz; AuthNotifier'ın hiçbir satırı değişmez.
final authRepositoryProvider = Provider<AuthRepository>((ref) => LocalAuthRepository());

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState());

  Future<void> login({required String username, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.login(username: username, password: password);
    result.when(
      success: (profile) {
        state = AuthState(status: AuthStatus.authenticated, profile: profile);
      },
      failure: (message) {
        AppLogger.warning('Giriş başarısız: $message');
        state = state.copyWith(isLoading: false, errorMessage: message);
      },
    );
  }

  Future<void> register({required String username, required RegisterMethod method}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.register(username: username, method: method);
    result.when(
      success: (profile) {
        state = AuthState(status: AuthStatus.authenticated, profile: profile);
      },
      failure: (message) {
        AppLogger.warning('Kayıt başarısız: $message');
        state = state.copyWith(isLoading: false, errorMessage: message);
      },
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
