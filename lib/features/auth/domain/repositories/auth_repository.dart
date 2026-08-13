import 'package:nucleus/features/profile/domain/entities/user_profile.dart';

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
