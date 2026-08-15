/// Supabase `profiles` + private `avatars` bucket. Custom photos use signed URLs.
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nucleus/core/errors/app_exception.dart' as app;
import 'package:nucleus/features/auth/domain/repositories/auth_repository.dart';
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<UserProfile?> getProfile(String userId) async {
    final row =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return _map(row);
  }

  @override
  Future<UserProfile> createProfile({
    required String id,
    required String name,
    required String email,
    required String encryptedDek,
    required String kekSalt,
    required Map<String, dynamic> kdfParams,
    String? avatarPresetId,
  }) async {
    final payload = {
      'id': id,
      'name': name,
      'email': email,
      'avatar_type': 'preset',
      'avatar_preset_id': avatarPresetId ?? '1',
      'theme_preference': 'system',
      'encrypted_dek': encryptedDek,
      'kek_salt': kekSalt,
      'kdf_params': kdfParams,
    };
    final row =
        await _client.from('profiles').insert(payload).select().single();
    return _map(row);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final payload = {
      'name': profile.name,
      'avatar_type': profile.avatarType.name,
      'avatar_preset_id': profile.avatarPresetId,
      'avatar_path': profile.avatarPath,
      'theme_preference': profile.themePreference.name,
      'encrypted_dek': profile.encryptedDek,
      'kek_salt': profile.kekSalt,
      'kdf_params': profile.kdfParams,
    };
    final row = await _client
        .from('profiles')
        .update(payload)
        .eq('id', profile.id)
        .select()
        .single();
    return _map(row);
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
  }) async {
    final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await File(filePath).readAsBytes();
    await _client.storage.from('avatars').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    return fileName;
  }

  @override
  /// Bucket is private; UI needs a time-limited signed URL, not a public path.
  Future<String?> getAvatarPublicUrl(String path) async {
    try {
      final signed = await _client.storage
          .from('avatars')
          .createSignedUrl(path, 60 * 60);
      return signed;
    } catch (e) {
      throw app.AppException('Failed to resolve avatar URL', cause: e);
    }
  }

  UserProfile _map(Map<String, dynamic> row) {
    return UserProfile(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      avatarType:
          avatarTypeFromString(row['avatar_type'] as String? ?? 'preset'),
      avatarPresetId: row['avatar_preset_id'] as String?,
      avatarPath: row['avatar_path'] as String?,
      themePreference: themePreferenceFromString(
        row['theme_preference'] as String? ?? 'system',
      ),
      encryptedDek: row['encrypted_dek'] as String,
      kekSalt: row['kek_salt'] as String,
      kdfParams: Map<String, dynamic>.from(row['kdf_params'] as Map? ?? {}),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
