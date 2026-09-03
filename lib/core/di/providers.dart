/// Riverpod wiring for shared services and repositories.
/// Feature notifiers live next to their pages, not here.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/network/connectivity_service.dart';
import 'package:nucleus/features/mfa/data/repositories/mfa_repository_impl.dart';
import 'package:nucleus/features/mfa/domain/repositories/mfa_repository.dart';
import 'package:nucleus/features/attachments/data/repositories/attachment_repository_impl.dart';
import 'package:nucleus/features/attachments/domain/repositories/attachment_repository.dart';
import 'package:nucleus/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:nucleus/features/auth/data/sign_in_mfa_pending_store.dart';
import 'package:nucleus/features/auth/domain/repositories/auth_repository.dart';
import 'package:nucleus/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:nucleus/features/unlock/data/biometric_unlock_store.dart';
import 'package:nucleus/features/vault/data/local/cloud_sync_exclusion_store.dart';
import 'package:nucleus/features/vault/data/local/local_vault_database.dart';
import 'package:nucleus/features/vault/data/repositories/cloud_vault_repository.dart';
import 'package:nucleus/features/vault/data/repositories/local_vault_repository.dart';
import 'package:nucleus/features/vault/data/repositories/folder_repository_impl.dart';
import 'package:nucleus/features/vault/data/repositories/vault_repository_impl.dart' as composite;
import 'package:nucleus/features/vault/domain/repositories/folder_repository.dart';
import 'package:nucleus/features/vault/domain/repositories/vault_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final vaultCryptoProvider = Provider<VaultCryptoService>((ref) {
  return VaultCryptoService();
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityServiceImpl();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(supabaseClientProvider),
    ref.watch(connectivityServiceProvider),
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    ref.watch(supabaseClientProvider),
    ref.watch(connectivityServiceProvider),
  );
});

final localVaultDatabaseProvider = Provider<LocalVaultDatabase>((ref) {
  return LocalVaultDatabase();
});

final cloudSyncExclusionStoreProvider = Provider<CloudSyncExclusionStore>((ref) {
  return CloudSyncExclusionStore();
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return composite.VaultRepositoryImpl(
    cloud: CloudVaultRepository(
      ref.watch(supabaseClientProvider),
      ref.watch(vaultCryptoProvider),
      ref.watch(connectivityServiceProvider),
    ),
    local: LocalVaultRepository(
      ref.watch(localVaultDatabaseProvider),
      ref.watch(vaultCryptoProvider),
    ),
    exclusions: ref.watch(cloudSyncExclusionStoreProvider),
  );
});

final mfaRepositoryProvider = Provider<MfaRepository>((ref) {
  return MfaRepositoryImpl(
    ref.watch(supabaseClientProvider),
    ref.watch(vaultCryptoProvider),
    ref.watch(connectivityServiceProvider),
  );
});

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return AttachmentRepositoryImpl(
    ref.watch(supabaseClientProvider),
    ref.watch(vaultCryptoProvider),
    ref.watch(connectivityServiceProvider),
  );
});

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepositoryImpl(
    ref.watch(supabaseClientProvider),
    ref.watch(connectivityServiceProvider),
  );
});

final biometricUnlockStoreProvider = Provider<BiometricUnlockStore>((ref) {
  return BiometricUnlockStore();
});

final signInMfaPendingStoreProvider = Provider<SignInMfaPendingStore>((ref) {
  return SignInMfaPendingStore();
});
