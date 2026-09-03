/// In-memory vault session: DEK, profile, lock status, reveal grace, auto-lock.
import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/features/auth/presentation/providers/pending_login_provider.dart';
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';
import 'package:nucleus/features/settings/domain/security_timeouts.dart';
import 'package:nucleus/features/settings/presentation/providers/security_preference_provider.dart';

enum VaultSessionStatus { locked, unlocking, unlocked }

/// Session snapshot. [dek] is only present while [status] is unlocked.
class VaultSessionState extends Equatable {
  const VaultSessionState({
    this.status = VaultSessionStatus.locked,
    this.dek,
    this.profile,
    this.profileResolved = false,
    this.signInMfaPending = false,
    this.revealUntil,
    this.error,
  });

  final VaultSessionStatus status;
  final Uint8List? dek;
  final UserProfile? profile;
  /// True after [loadProfile] so a missing profile is distinct from "not loaded yet".
  final bool profileResolved;
  /// Full sign-in still needs App Login MFA (persisted across app restarts).
  final bool signInMfaPending;
  final DateTime? revealUntil;
  final String? error;

  bool get isUnlocked => status == VaultSessionStatus.unlocked && dek != null;

  /// True when a reveal/copy can skip a new biometric/password prompt.
  bool get canRevealSecrets {
    if (!isUnlocked) return false;
    if (revealUntil == null) return false;
    return DateTime.now().isBefore(revealUntil!);
  }

  VaultSessionState copyWith({
    VaultSessionStatus? status,
    Uint8List? dek,
    UserProfile? profile,
    bool? profileResolved,
    bool? signInMfaPending,
    DateTime? revealUntil,
    String? error,
    bool clearDek = false,
    bool clearError = false,
    bool clearReveal = false,
    bool clearProfile = false,
  }) {
    return VaultSessionState(
      status: status ?? this.status,
      dek: clearDek ? null : (dek ?? this.dek),
      profile: clearProfile ? null : (profile ?? this.profile),
      profileResolved: profileResolved ?? this.profileResolved,
      signInMfaPending: signInMfaPending ?? this.signInMfaPending,
      revealUntil: clearReveal ? null : (revealUntil ?? this.revealUntil),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [status, profile, profileResolved, signInMfaPending, revealUntil, error, dek?.length];
}

/// Owns unlock, lock, logout, and the two security timers (auto-lock + grace).
class VaultSessionNotifier extends StateNotifier<VaultSessionState> {
  VaultSessionNotifier(this._ref) : super(const VaultSessionState()) {
    _ref.listen(securityPreferenceProvider, (prev, next) {
      if (!state.isUnlocked) return;
      _scheduleInactivityWatch();
      if (next.revealGrace.duration == null) {
        state = state.copyWith(clearReveal: true);
      }
    });
  }

  final Ref _ref;

  DateTime? _lastActivityAt;
  Timer? _inactivityTimer;

  Duration? get _revealGraceDuration =>
      _ref.read(securityPreferenceProvider).revealGrace.duration;

  Duration? get _autoLockDuration =>
      _ref.read(securityPreferenceProvider).autoLock.duration;

  DateTime? _revealUntilFromNow() {
    final grace = _revealGraceDuration;
    if (grace == null) return null;
    return DateTime.now().add(grace);
  }

  /// Records foreground interaction used by the inactivity auto-lock timer.
  void touchActivity() {
    if (!state.isUnlocked) return;
    _lastActivityAt = DateTime.now();
  }

  /// Polls every 2s rather than a one-shot timer so preference changes apply
  /// without restarting the whole session.
  void _scheduleInactivityWatch() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;

    final timeout = _autoLockDuration;
    if (!state.isUnlocked || timeout == null) return;

    _lastActivityAt ??= DateTime.now();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!state.isUnlocked) {
        _inactivityTimer?.cancel();
        _inactivityTimer = null;
        return;
      }
      _evaluateInactivityLock();
    });
  }

  /// Locks when wall-clock inactivity exceeds the auto-lock preference (foreground
  /// timer and [onAppResumed] after background both use this).
  void _evaluateInactivityLock() {
    if (!state.isUnlocked) return;
    final timeout = _autoLockDuration;
    if (timeout == null) return;
    final last = _lastActivityAt;
    if (last == null) return;
    if (DateTime.now().difference(last) >= timeout) {
      lock();
    }
  }

  /// Called when the app returns to foreground; timers may not fire while paused.
  void onAppResumed() {
    _evaluateInactivityLock();
  }

  void _onUnlocked({
    required Uint8List dek,
    required UserProfile? profile,
    bool clearSignInMfaPending = false,
  }) {
    _lastActivityAt = DateTime.now();
    state = VaultSessionState(
      status: VaultSessionStatus.unlocked,
      dek: dek,
      profile: profile,
      profileResolved: true,
      signInMfaPending: clearSignInMfaPending ? false : state.signInMfaPending,
      revealUntil: _revealUntilFromNow(),
    );
    _scheduleInactivityWatch();
  }

  /// Loads wrapped-DEK metadata before the unlock screen (does not unwrap).
  Future<void> loadProfile(String userId) async {
    final profile =
        await _ref.read(profileRepositoryProvider).getProfile(userId);
    var signInMfaPending = false;
    if (profile != null && profile.loginTotpEnabled) {
      final staleInStore =
          await _ref.read(signInMfaPendingStoreProvider).isPending(userId);
      if (staleInStore) {
        if (_ref.read(pendingLoginPasswordProvider) != null) {
          signInMfaPending = true;
        } else {
          await abandonIncompleteSignIn(userId);
          return;
        }
      }
    }
    state = state.copyWith(
      profile: profile,
      profileResolved: true,
      signInMfaPending: signInMfaPending,
      clearProfile: profile == null,
    );
  }

  /// Incomplete sign-in MFA after process death: sign out and clear flags.
  Future<void> abandonIncompleteSignIn(String userId) async {
    await _ref.read(signInMfaPendingStoreProvider).clearPending(userId);
    await _ref.read(biometricUnlockStoreProvider).clearDek(userId);
    _ref.read(pendingLoginPasswordProvider.notifier).state = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _lastActivityAt = null;
    await _ref.read(authRepositoryProvider).signOut();
    state = const VaultSessionState();
  }

  /// After password sign-in when App Login MFA is enabled (before TOTP completes).
  Future<void> markSignInMfaRequired() async {
    final userId = _ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return;
    await _ref.read(signInMfaPendingStoreProvider).setPending(userId);
    state = state.copyWith(signInMfaPending: true);
  }

  /// After successful login-totp or when abandoning the sign-in MFA step via logout.
  Future<void> clearSignInMfaRequired() async {
    final userId = _ref.read(authRepositoryProvider).currentUserId;
    if (userId != null) {
      await _ref.read(signInMfaPendingStoreProvider).clearPending(userId);
    }
    state = state.copyWith(signInMfaPending: false);
  }

  bool _mustCompleteSignInMfa(UserProfile profile) {
    return profile.loginTotpEnabled && state.signInMfaPending;
  }

  /// Unwraps the DEK with the master password and caches it for biometrics.
  Future<void> unlockWithPassword(String masterPassword) async {
    final auth = _ref.read(authRepositoryProvider);
    final userId = auth.currentUserId;
    if (userId == null) {
      state = state.copyWith(error: 'Not signed in');
      return;
    }
    state = state.copyWith(
      status: VaultSessionStatus.unlocking,
      clearError: true,
    );
    try {
      final profileRepo = _ref.read(profileRepositoryProvider);
      final profile = await profileRepo.getProfile(userId);
      if (profile == null) {
        throw const CryptoException('Profile not found');
      }
      if (_mustCompleteSignInMfa(profile)) {
        state = state.copyWith(
          status: VaultSessionStatus.locked,
          clearDek: true,
          error: 'Enter your authenticator code to finish signing in',
        );
        return;
      }
      final crypto = _ref.read(vaultCryptoProvider);
      final dek = await crypto.unwrapDek(
        masterPassword: masterPassword,
        wrapped: WrappedDek(
          encryptedDekBase64: profile.encryptedDek,
          saltBase64: profile.kekSalt,
          kdfParams: KdfParams.fromJson(profile.kdfParams),
        ),
      );
      await _ref.read(biometricUnlockStoreProvider).saveDek(userId, dek);
      _onUnlocked(dek: dek, profile: profile);
    } catch (e) {
      final offline = e is OfflineException ||
          isNetworkError(e) ||
          !await _ref.read(connectivityServiceProvider).hasConnection();
      state = state.copyWith(
        status: VaultSessionStatus.locked,
        clearDek: true,
        error: offline
            ? await userFacingErrorMessage(
                _ref.read(connectivityServiceProvider),
                e,
              )
            : 'Wrong master password',
      );
    }
  }

  /// Verifies master password without granting reveal grace or changing session.
  Future<bool> verifyMasterPassword(String masterPassword) async {
    final auth = _ref.read(authRepositoryProvider);
    final userId = auth.currentUserId;
    if (userId == null) return false;
    try {
      final profile = state.profile ??
          await _ref.read(profileRepositoryProvider).getProfile(userId);
      if (profile == null) return false;
      final crypto = _ref.read(vaultCryptoProvider);
      final dek = await crypto.unwrapDek(
        masterPassword: masterPassword,
        wrapped: WrappedDek(
          encryptedDekBase64: profile.encryptedDek,
          saltBase64: profile.kekSalt,
          kdfParams: KdfParams.fromJson(profile.kdfParams),
        ),
      );
      if (!state.isUnlocked || state.dek == null) return true;
      return _bytesEqual(dek, state.dek!);
    } catch (_) {
      return false;
    }
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Verifies master password while the vault is already unlocked.
  /// Does not flip status to [VaultSessionStatus.unlocking] (avoids router
  /// redirect) and does not lock on failure.
  Future<bool> confirmMasterPasswordForReveal(String masterPassword) async {
    if (!state.isUnlocked) return false;
    final auth = _ref.read(authRepositoryProvider);
    final userId = auth.currentUserId;
    if (userId == null) return false;
    try {
      final profile = state.profile ??
          await _ref.read(profileRepositoryProvider).getProfile(userId);
      if (profile == null) return false;
      final crypto = _ref.read(vaultCryptoProvider);
      await crypto.unwrapDek(
        masterPassword: masterPassword,
        wrapped: WrappedDek(
          encryptedDekBase64: profile.encryptedDek,
          saltBase64: profile.kekSalt,
          kdfParams: KdfParams.fromJson(profile.kdfParams),
        ),
      );
      grantRevealGrace();
      touchActivity();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// OS biometric prompt, then read the device-stored DEK. Master password is
  /// not involved after a successful first unwrap on this device.
  Future<bool> unlockWithBiometrics() async {
    final auth = _ref.read(authRepositoryProvider);
    final userId = auth.currentUserId;
    if (userId == null) return false;
    final store = _ref.read(biometricUnlockStoreProvider);
    final ok = await store.authenticate(reason: 'Unlock your vault');
    if (!ok) return false;
    final dek = await store.readDek(userId);
    if (dek == null) return false;
    final profile = await _ref.read(profileRepositoryProvider).getProfile(userId);
    if (profile != null && _mustCompleteSignInMfa(profile)) {
      return false;
    }
    _onUnlocked(dek: dek, profile: profile);
    return true;
  }

  /// Biometric gate for reveal/copy. Returns false so the UI can fall back to
  /// master password when biometrics are unavailable or cancelled.
  Future<bool> gateForReveal({
    String reason = 'Reveal sensitive data',
  }) async {
    if (state.canRevealSecrets) return true;
    final store = _ref.read(biometricUnlockStoreProvider);
    final canBio = await store.canCheckBiometrics();
    if (canBio) {
      final ok = await store.authenticate(reason: reason);
      if (ok && state.dek != null) {
        grantRevealGrace();
        touchActivity();
        return true;
      }
    }
    return false;
  }

  void grantRevealGrace() {
    final until = _revealUntilFromNow();
    if (until == null) {
      state = state.copyWith(clearReveal: true);
      return;
    }
    state = state.copyWith(revealUntil: until);
  }

  /// Drops the in-memory DEK but keeps [profile] so unlock UI can still greet.
  void lock() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _lastActivityAt = null;
    state = VaultSessionState(
      status: VaultSessionStatus.locked,
      profile: state.profile,
      profileResolved: state.profileResolved,
      signInMfaPending: state.signInMfaPending,
    );
  }

  /// Clears the device DEK, signs out of Auth, and resets session state.
  Future<void> logout() async {
    final userId = _ref.read(authRepositoryProvider).currentUserId;
    if (userId != null) {
      await _ref.read(biometricUnlockStoreProvider).clearDek(userId);
      await _ref.read(signInMfaPendingStoreProvider).clearPending(userId);
    }
    await _ref.read(authRepositoryProvider).signOut();
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _lastActivityAt = null;
    state = const VaultSessionState();
  }

  void setProfile(UserProfile profile) {
    state = state.copyWith(profile: profile);
  }

  /// Used after signup so the user skips a second unlock.
  void openUnlockedSession({
    required Uint8List dek,
    required UserProfile profile,
  }) {
    _onUnlocked(dek: dek, profile: profile, clearSignInMfaPending: true);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}

final vaultSessionProvider =
    StateNotifierProvider<VaultSessionNotifier, VaultSessionState>((ref) {
  return VaultSessionNotifier(ref);
});
