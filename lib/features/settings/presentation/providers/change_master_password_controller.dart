/// Change-master-password flow: verify, re-wrap DEK, persist, then Auth update.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/features/mfa/data/login_mfa_service.dart';
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';

class ChangeMasterPasswordState {
  const ChangeMasterPasswordState({
    this.loading = false,
    this.error,
    this.success = false,
  });

  final bool loading;
  final String? error;
  final bool success;

  ChangeMasterPasswordState copyWith({
    bool? loading,
    String? error,
    bool? success,
    bool clearError = false,
  }) {
    return ChangeMasterPasswordState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      success: success ?? this.success,
    );
  }
}

/// Coordinated master-password change:
/// verify old password → re-wrap DEK → persist profile wrap → update Auth
/// password. Vault item ciphertext is untouched (DEK unchanged).
class ChangeMasterPasswordController
    extends StateNotifier<ChangeMasterPasswordState> {
  ChangeMasterPasswordController(this._ref)
      : super(const ChangeMasterPasswordState());

  final Ref _ref;

  /// Same mobile-friendly Argon2id params as signup.
  static const _kdfParams = KdfParams(
    memory: 19456,
    iterations: 2,
    parallelism: 2,
  );

  Future<bool> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(loading: true, clearError: true, success: false);

    if (newPassword.length < 8) {
      state = state.copyWith(
        loading: false,
        error: 'New master password must be at least 8 characters',
      );
      return false;
    }
    if (currentPassword == newPassword) {
      state = state.copyWith(
        loading: false,
        error: 'New master password must be different from the current one',
      );
      return false;
    }

    final auth = _ref.read(authRepositoryProvider);
    final userId = auth.currentUserId;
    if (userId == null) {
      state = state.copyWith(loading: false, error: 'Not signed in');
      return false;
    }

    final session = _ref.read(vaultSessionProvider);
    if (!session.isUnlocked || session.dek == null) {
      state = state.copyWith(
        loading: false,
        error: 'Unlock your vault before changing the master password',
      );
      return false;
    }

    final crypto = _ref.read(vaultCryptoProvider);
    final profileRepo = _ref.read(profileRepositoryProvider);

    UserProfile? profile = session.profile;
    profile ??= await profileRepo.getProfile(userId);
    if (profile == null) {
      state = state.copyWith(loading: false, error: 'Profile not found');
      return false;
    }

    final previousWrap = WrappedDek(
      encryptedDekBase64: profile.encryptedDek,
      saltBase64: profile.kekSalt,
      kdfParams: KdfParams.fromJson(profile.kdfParams),
    );

    late final Uint8List verifiedDek;
    try {
      verifiedDek = await crypto.unwrapDek(
        masterPassword: currentPassword,
        wrapped: previousWrap,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Current master password is incorrect',
      );
      return false;
    }

    // Ensure the password that unwraps matches the open vault DEK.
    if (!_bytesEqual(verifiedDek, session.dek!)) {
      state = state.copyWith(
        loading: false,
        error: 'Vault session is out of sync. Lock and unlock, then try again.',
      );
      return false;
    }

    final newWrap = await crypto.rewrapDek(
      dek: verifiedDek,
      newMasterPassword: newPassword,
      params: _kdfParams,
    );

    final profileWithNewWrap = profile.copyWith(
      encryptedDek: newWrap.encryptedDekBase64,
      kekSalt: newWrap.saltBase64,
      kdfParams: newWrap.kdfParams.toJson(),
    );

    var profileToSave = profileWithNewWrap;
    if (profile.loginTotpEnabled) {
      final loginMfa = LoginMfaService(crypto);
      final totpRewrap = await loginMfa.rewrapTotpSecret(
        oldMasterPassword: currentPassword,
        newMasterPassword: newPassword,
        profile: profile,
      );
      profileToSave = profileToSave.copyWith(
        encryptedLoginTotpSecret: totpRewrap.ciphertext,
        loginTotpSecretNonce: totpRewrap.nonce,
      );
      final backupRewrap = await loginMfa.rewrapBackupPayload(
        oldMasterPassword: currentPassword,
        newMasterPassword: newPassword,
        profile: profile,
      );
      if (backupRewrap != null) {
        profileToSave = profileToSave.copyWith(
          encryptedLoginBackupPayload: backupRewrap.ciphertext,
          loginBackupPayloadNonce: backupRewrap.nonce,
        );
      }
    }

    UserProfile? savedProfile;
    try {
      // Persist wrap first so Auth password and wrap stay recoverable together.
      savedProfile = await profileRepo.updateProfile(profileToSave);

      // Refresh Auth session proof with the current password, then rotate it.
      await auth.signIn(email: profile.email, password: currentPassword);
      await auth.updatePassword(newPassword);
    } catch (e) {
      if (savedProfile != null) {
        try {
          await profileRepo.updateProfile(
            profile.copyWith(
              encryptedDek: previousWrap.encryptedDekBase64,
              kekSalt: previousWrap.saltBase64,
              kdfParams: previousWrap.kdfParams.toJson(),
            ),
          );
        } catch (_) {
          // Best-effort rollback; surface the original failure below.
        }
      }
      state = state.copyWith(
        loading: false,
        error: await userFacingErrorMessage(
          _ref.read(connectivityServiceProvider),
          e is AppException
              ? e
              : AppException('Could not change master password. Please try again.',
                  cause: e),
        ),
      );
      return false;
    }

    // DEK is unchanged — biometric unlock material remains valid.
    _ref.read(vaultSessionProvider.notifier).setProfile(savedProfile);
    state = state.copyWith(loading: false, success: true);
    return true;
  }

  /// Constant-time-ish compare so we do not early-return on the first mismatch.
  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

final changeMasterPasswordControllerProvider = StateNotifierProvider.autoDispose<
    ChangeMasterPasswordController, ChangeMasterPasswordState>((ref) {
  return ChangeMasterPasswordController(ref);
});
