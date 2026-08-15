/// Riverpod wiring for shared services and repositories.
/// Feature notifiers live next to their pages, not here.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:nucleus/features/auth/domain/repositories/auth_repository.dart';
import 'package:nucleus/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:nucleus/features/unlock/data/biometric_unlock_store.dart';
import 'package:nucleus/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:nucleus/features/vault/domain/repositories/vault_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final vaultCryptoProvider = Provider<VaultCryptoService>((ref) {
  return VaultCryptoService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(supabaseClientProvider));
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepositoryImpl(
    ref.watch(supabaseClientProvider),
    ref.watch(vaultCryptoProvider),
  );
});

final biometricUnlockStoreProvider = Provider<BiometricUnlockStore>((ref) {
  return BiometricUnlockStore();
});
