import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vaultify/core/crypto/vault_crypto_service.dart';
import 'package:vaultify/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vaultify/features/auth/domain/repositories/auth_repository.dart';
import 'package:vaultify/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:vaultify/features/unlock/data/biometric_unlock_store.dart';
import 'package:vaultify/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:vaultify/features/vault/domain/repositories/vault_repository.dart';

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
