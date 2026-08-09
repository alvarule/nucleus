import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultify/core/di/providers.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/profile/domain/entities/user_profile.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';

class AvatarWidget extends ConsumerWidget {
  const AvatarWidget({
    super.key,
    required this.profile,
    this.size = 48,
  });

  final UserProfile profile;
  final double size;

  bool get _hasCustom =>
      profile.avatarType == AvatarType.custom &&
      profile.avatarPath != null &&
      profile.avatarPath!.isNotEmpty;

  bool get _hasPreset =>
      profile.avatarType == AvatarType.preset &&
      profile.avatarPresetId != null &&
      profile.avatarPresetId!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (_hasCustom) {
      return FutureBuilder<String?>(
        future: ref
            .read(profileRepositoryProvider)
            .getAvatarPublicUrl(profile.avatarPath!),
        builder: (context, snap) {
          if (snap.data != null) {
            return CircleAvatar(
              radius: size / 2,
              backgroundImage: NetworkImage(snap.data!),
            );
          }
          return _placeholder(colors);
        },
      );
    }

    if (_hasPreset) {
      final id = profile.avatarPresetId!;
      return ClipOval(
        child: Image.asset(
          'assets/avatars/$id.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholder(colors),
        ),
      );
    }

    return _placeholder(colors);
  }

  Widget _placeholder(AppColors colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AppIcon('user', size: size * 0.45, color: colors.primary),
    );
  }
}
