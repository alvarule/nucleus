import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultify/core/crypto/vault_crypto_service.dart';
import 'package:vaultify/core/di/providers.dart';
import 'package:vaultify/core/errors/app_exception.dart';
import 'package:vaultify/features/profile/domain/entities/user_profile.dart';

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
  VaultSessionNotifier(this._ref) : super(const VaultSessionState());

  final Ref _ref;

  static const _revealGrace = Duration(minutes: 2);

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
      state = VaultSessionState(
        status: VaultSessionStatus.unlocked,
        dek: dek,
        profile: profile,
        revealUntil: DateTime.now().add(_revealGrace),
      );
    } catch (e) {
      state = state.copyWith(
        status: VaultSessionStatus.locked,
        clearDek: true,
        error: 'Wrong master password',
      );
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
    state = VaultSessionState(
      status: VaultSessionStatus.unlocked,
      dek: dek,
      profile: profile,
      revealUntil: DateTime.now().add(_revealGrace),
    );
    return true;
  }

  Future<bool> gateForReveal() async {
    if (state.canRevealSecrets) return true;
    final store = _ref.read(biometricUnlockStoreProvider);
    final canBio = await store.canCheckBiometrics();
    if (canBio) {
      final ok = await store.authenticate(reason: 'Reveal sensitive data');
      if (ok && state.dek != null) {
        state = state.copyWith(revealUntil: DateTime.now().add(_revealGrace));
        return true;
      }
    }
    return false;
  }

  void grantRevealGrace() {
    state = state.copyWith(revealUntil: DateTime.now().add(_revealGrace));
  }

  void lock() {
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
    state = const VaultSessionState();
  }

  void setProfile(UserProfile profile) {
    state = state.copyWith(profile: profile);
  }

  void openUnlockedSession({
    required Uint8List dek,
    required UserProfile profile,
  }) {
    state = VaultSessionState(
      status: VaultSessionStatus.unlocked,
      dek: dek,
      profile: profile,
      revealUntil: DateTime.now().add(_revealGrace),
    );
  }
}

final vaultSessionProvider =
    StateNotifierProvider<VaultSessionNotifier, VaultSessionState>((ref) {
  return VaultSessionNotifier(ref);
});
