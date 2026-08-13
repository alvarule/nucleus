import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';
import 'package:nucleus/features/settings/domain/security_timeouts.dart';
import 'package:nucleus/features/settings/presentation/providers/security_preference_provider.dart';

enum VaultSessionStatus { locked, unlocking, unlocked }

class VaultSessionState extends Equatable {
  const VaultSessionState({
    this.status = VaultSessionStatus.locked,
    this.dek,
    this.profile,
    this.revealUntil,
    this.error,
  });

  final VaultSessionStatus status;
  final Uint8List? dek;
  final UserProfile? profile;
  final DateTime? revealUntil;
  final String? error;

  bool get isUnlocked => status == VaultSessionStatus.unlocked && dek != null;

  bool get canRevealSecrets {
    if (!isUnlocked) return false;
    if (revealUntil == null) return false;
    return DateTime.now().isBefore(revealUntil!);
  }

  VaultSessionState copyWith({
    VaultSessionStatus? status,
    Uint8List? dek,
    UserProfile? profile,
    DateTime? revealUntil,
    String? error,
    bool clearDek = false,
    bool clearError = false,
    bool clearReveal = false,
  }) {
    return VaultSessionState(
      status: status ?? this.status,
      dek: clearDek ? null : (dek ?? this.dek),
      profile: profile ?? this.profile,
      revealUntil: clearReveal ? null : (revealUntil ?? this.revealUntil),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, profile, revealUntil, error, dek?.length];
}

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

  void touchActivity() {
    if (!state.isUnlocked) return;
    _lastActivityAt = DateTime.now();
  }

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
      final last = _lastActivityAt;
      if (last == null) return;
      if (DateTime.now().difference(last) >= timeout) {
        lock();
      }
    });
  }

  void _onUnlocked({
    required Uint8List dek,
    required UserProfile? profile,
  }) {
    _lastActivityAt = DateTime.now();
    state = VaultSessionState(
      status: VaultSessionStatus.unlocked,
      dek: dek,
      profile: profile,
      revealUntil: _revealUntilFromNow(),
    );
    _scheduleInactivityWatch();
  }

  Future<void> loadProfile(String userId) async {
    final profile = await _ref.read(profileRepositoryProvider).getProfile(userId);
    state = state.copyWith(profile: profile);
  }

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
      state = state.copyWith(
        status: VaultSessionStatus.locked,
        clearDek: true,
        error: 'Wrong master password',
      );
    }
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
    _onUnlocked(dek: dek, profile: profile);
    return true;
  }

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

  void lock() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _lastActivityAt = null;
    state = VaultSessionState(
      status: VaultSessionStatus.locked,
      profile: state.profile,
    );
  }

  Future<void> logout() async {
    final userId = _ref.read(authRepositoryProvider).currentUserId;
    if (userId != null) {
      await _ref.read(biometricUnlockStoreProvider).clearDek(userId);
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

  void openUnlockedSession({
    required Uint8List dek,
    required UserProfile profile,
  }) {
    _onUnlocked(dek: dek, profile: profile);
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
