import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultify/core/di/providers.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/profile/domain/entities/user_profile.dart';

class AvatarWidget extends ConsumerWidget {
  const AvatarWidget({
    super.key,
    required this.profile,
    this.size = 48,
  });

  final UserProfile profile;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (profile.avatarType == AvatarType.custom &&
        profile.avatarPath != null &&
        profile.avatarPath!.isNotEmpty) {
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
          return _preset(colors);
        },
      );
    }
    return _preset(colors);
  }

  Widget _preset(AppColors colors) {
    final id = profile.avatarPresetId ?? '1';
    final assetPath = 'assets/avatars/$id.png';
    return ClipOval(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: colors.primarySoft,
            alignment: Alignment.center,
            child: Text(
              id,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.28,
              ),
            ),
          );
        },
      ),
    );
  }
}
