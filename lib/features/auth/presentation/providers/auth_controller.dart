/// Login/signup form state, email-link signup, and vault-setup crypto bootstrap.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';

/// Loading and error flags for login/signup/vault-setup forms.
class AuthFormState {
  const AuthFormState({
    this.loading = false,
    this.error,
  });

  final bool loading;
  final String? error;

  AuthFormState copyWith({bool? loading, String? error, bool clearError = false}) {
    return AuthFormState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends StateNotifier<AuthFormState> {
  AuthController(this._ref) : super(const AuthFormState());

  final Ref _ref;

  /// Name + email only. Sends the confirmation link; no DEK yet.
  Future<bool> requestSignupLink({
    required String name,
    required String email,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _ref.read(authRepositoryProvider).requestSignupLink(
            email: email,
            name: name,
          );
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: await userFacingErrorMessage(
          _ref.read(connectivityServiceProvider),
          e,
        ),
      );
      return false;
    }
  }

  Future<bool> resendSignupLink({
    required String name,
    required String email,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _ref.read(authRepositoryProvider).resendSignupLink(
            email: email,
            name: name,
          );
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: await userFacingErrorMessage(
          _ref.read(connectivityServiceProvider),
          e,
        ),
      );
      return false;
    }
  }

  /// After the email link establishes a session: set Auth password, wrap DEK, profile.
  Future<bool> completeVaultSetup({
    required String masterPassword,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final auth = _ref.read(authRepositoryProvider);
      final userId = auth.currentUserId;
      if (userId == null) {
        throw const AuthFailure('Session expired. Open the email link again.');
      }

      try {
        await auth.updatePassword(masterPassword);
      } on AuthFailure catch (e) {
        // Retry after a failed previous setup: Auth password may already match.
        final lower = e.message.toLowerCase();
        if (!lower.contains('different') && !lower.contains('same_password')) {
          rethrow;
        }
      }

      final crypto = _ref.read(vaultCryptoProvider);
      final dek = crypto.generateDek();
      const params = KdfParams(memory: 19456, iterations: 2, parallelism: 2);
      final wrapped = await crypto.wrapDek(
        dek: dek,
        masterPassword: masterPassword,
        params: params,
      );

      final name = auth.currentUserName ??
          (auth.currentUserEmail ?? 'User').split('@').first;
      final email = auth.currentUserEmail ?? '';

      final profile = await _ref.read(profileRepositoryProvider).createProfile(
            id: userId,
            name: name,
            email: email,
            encryptedDek: wrapped.encryptedDekBase64,
            kekSalt: wrapped.saltBase64,
            kdfParams: wrapped.kdfParams.toJson(),
            avatarPresetId: '1',
          );

      await _ref.read(biometricUnlockStoreProvider).saveDek(userId, dek);
      _ref.read(vaultSessionProvider.notifier).openUnlockedSession(
            dek: dek,
            profile: profile,
          );
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: await userFacingErrorMessage(
          _ref.read(connectivityServiceProvider),
          e,
        ),
      );
      return false;
    }
  }

  /// Email+password Auth, then unwrap DEK via [VaultSessionNotifier].
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          );
      final userId = _ref.read(authRepositoryProvider).currentUserId;
      if (userId != null) {
        await _ref.read(vaultSessionProvider.notifier).loadProfile(userId);
      }
      final profile = _ref.read(vaultSessionProvider).profile;
      if (profile == null) {
        state = state.copyWith(loading: false);
        return true;
      }
      await _ref.read(vaultSessionProvider.notifier).unlockWithPassword(password);
      final session = _ref.read(vaultSessionProvider);
      if (!session.isUnlocked) {
        state = state.copyWith(
          loading: false,
          error: session.error ?? 'Could not unlock vault',
        );
        return false;
      }
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: await userFacingErrorMessage(
          _ref.read(connectivityServiceProvider),
          e,
        ),
      );
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthFormState>((ref) {
  return AuthController(ref);
});
