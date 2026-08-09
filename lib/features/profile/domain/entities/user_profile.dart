import 'package:equatable/equatable.dart';

enum AvatarType { preset, custom }

enum ThemePreference { system, light, dark }

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarType,
    this.avatarPresetId,
    this.avatarPath,
    required this.themePreference,
    required this.encryptedDek,
    required this.kekSalt,
    required this.kdfParams,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final AvatarType avatarType;
  final String? avatarPresetId;
  final String? avatarPath;
  final ThemePreference themePreference;
  final String encryptedDek;
  final String kekSalt;
  final Map<String, dynamic> kdfParams;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? name,
    AvatarType? avatarType,
    String? avatarPresetId,
    String? avatarPath,
    ThemePreference? themePreference,
    String? encryptedDek,
    String? kekSalt,
    Map<String, dynamic>? kdfParams,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email,
      avatarType: avatarType ?? this.avatarType,
      avatarPresetId: avatarPresetId ?? this.avatarPresetId,
      avatarPath: avatarPath ?? this.avatarPath,
      themePreference: themePreference ?? this.themePreference,
      encryptedDek: encryptedDek ?? this.encryptedDek,
      kekSalt: kekSalt ?? this.kekSalt,
      kdfParams: kdfParams ?? this.kdfParams,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        avatarType,
        avatarPresetId,
        avatarPath,
        themePreference,
        encryptedDek,
        kekSalt,
        themePreference,
      ];
}

ThemePreference themePreferenceFromString(String value) {
  return ThemePreference.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ThemePreference.system,
  );
}

AvatarType avatarTypeFromString(String value) {
  return AvatarType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => AvatarType.preset,
  );
}
