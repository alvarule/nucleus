import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';

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

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final auth = _ref.read(authRepositoryProvider);
      final crypto = _ref.read(vaultCryptoProvider);
      final profileRepo = _ref.read(profileRepositoryProvider);

      final userId = await auth.signUp(
        email: email,
        password: password,
        name: name,
      );

      // If email confirmation is required, session may be null — try sign-in.
      if (auth.currentUserId == null) {
        await auth.signIn(email: email, password: password);
      }

      final dek = crypto.generateDek();
      const params = KdfParams(memory: 19456, iterations: 2, parallelism: 2);
      final wrapped = await crypto.wrapDek(
        dek: dek,
        masterPassword: password,
        params: params,
      );

      final profile = await profileRepo.createProfile(
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
        error: e is AppException ? e.message : e.toString(),
      );
      return false;
    }
  }

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
        error: e is AppException ? e.message : e.toString(),
      );
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthFormState>((ref) {
  return AuthController(ref);
});
