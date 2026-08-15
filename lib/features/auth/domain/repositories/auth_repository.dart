/// Auth and profile repository contracts (domain). Implementations live under
/// `features/*/data`. Profile lives here because signup creates both the user
/// and the wrapped-DEK profile row.
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';

/// Supabase Auth operations used by login, signup, logout, and password change.
abstract class AuthRepository {
  Stream<String?> authStateChanges();

  String? get currentUserId;

  Future<String> signUp({
    required String email,
    required String password,
    required String name,
  });

  Future<String> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> updatePassword(String newPassword);
}

/// `profiles` table + avatars storage. Holds wrapped DEK metadata, not secrets.
abstract class ProfileRepository {
  Future<UserProfile?> getProfile(String userId);

  Future<UserProfile> createProfile({
    required String id,
    required String name,
    required String email,
    required String encryptedDek,
    required String kekSalt,
    required Map<String, dynamic> kdfParams,
    String? avatarPresetId,
  });

  Future<UserProfile> updateProfile(UserProfile profile);

  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
  });

  Future<String?> getAvatarPublicUrl(String path);
}
