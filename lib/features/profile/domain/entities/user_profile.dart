/// Profile entity plus avatar/theme enums. Wrapped DEK fields live on this row.
import 'package:equatable/equatable.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';

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
    this.defaultSyncMode = VaultSyncMode.cloud,
    this.loginTotpEnabled = false,
    this.encryptedLoginTotpSecret,
    this.loginTotpSecretNonce,
    this.encryptedLoginBackupPayload,
    this.loginBackupPayloadNonce,
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
  final VaultSyncMode defaultSyncMode;
  final bool loginTotpEnabled;
  final String? encryptedLoginTotpSecret;
  final String? loginTotpSecretNonce;
  final String? encryptedLoginBackupPayload;
  final String? loginBackupPayloadNonce;

  UserProfile copyWith({
    String? name,
    AvatarType? avatarType,
    String? avatarPresetId,
    String? avatarPath,
    ThemePreference? themePreference,
    String? encryptedDek,
    String? kekSalt,
    Map<String, dynamic>? kdfParams,
    VaultSyncMode? defaultSyncMode,
    bool? loginTotpEnabled,
    String? encryptedLoginTotpSecret,
    String? loginTotpSecretNonce,
    bool clearLoginTotpSecret = false,
    String? encryptedLoginBackupPayload,
    String? loginBackupPayloadNonce,
    bool clearLoginBackupPayload = false,
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
      defaultSyncMode: defaultSyncMode ?? this.defaultSyncMode,
      loginTotpEnabled: loginTotpEnabled ?? this.loginTotpEnabled,
      encryptedLoginTotpSecret: clearLoginTotpSecret
          ? null
          : (encryptedLoginTotpSecret ?? this.encryptedLoginTotpSecret),
      loginTotpSecretNonce: clearLoginTotpSecret
          ? null
          : (loginTotpSecretNonce ?? this.loginTotpSecretNonce),
      encryptedLoginBackupPayload: clearLoginBackupPayload ||
              clearLoginTotpSecret
          ? null
          : (encryptedLoginBackupPayload ??
              this.encryptedLoginBackupPayload),
      loginBackupPayloadNonce: clearLoginBackupPayload ||
              clearLoginTotpSecret
          ? null
          : (loginBackupPayloadNonce ?? this.loginBackupPayloadNonce),
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
        defaultSyncMode,
        loginTotpEnabled,
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
