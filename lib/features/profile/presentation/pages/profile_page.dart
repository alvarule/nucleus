/// Edit name and avatar. Theme/lock/logout live on Settings, not here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';
import 'package:nucleus/features/profile/presentation/widgets/avatar_widget.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _name;
  late TextEditingController _email;
  final _nameFocus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(vaultSessionProvider).profile;
    _name = TextEditingController(text: profile?.name ?? '');
    _email = TextEditingController(text: profile?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final profile = ref.watch(vaultSessionProvider).profile;

    if (profile == null) {
      return const Scaffold(body: Center(child: Text('No profile')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: AppIcon('back', color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(profile),
            child: _saving
                ? SizedBox(
                    width: scale.s(20),
                    height: scale.s(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: scale.fontMd,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(scale.md, scale.md, scale.md, scale.lg),
        children: [
          Center(
            child: Hero(
              tag: 'profile_avatar',
              child: AvatarWidget(profile: profile, size: scale.s(88)),
            ),
          ),
          SizedBox(height: scale.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AvatarAction(
                label: 'Choose avatar',
                onTap: () => _pickPreset(profile),
              ),
              SizedBox(width: scale.sm),
              _AvatarAction(
                label: 'Upload photo',
                onTap: () => _uploadCustom(profile),
              ),
            ],
          ),
          SizedBox(height: scale.lg),
          VaultTextField(
            controller: _name,
            focusNode: _nameFocus,
            label: 'Name',
            prefixIcon: 'user',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(profile),
          ),
          SizedBox(height: scale.md),
          VaultTextField(
            controller: _email,
            label: 'Email',
            prefixIcon: 'mail',
            enabled: false,
          ),
        ],
      ),
    );
  }

  Future<void> _save(UserProfile profile) async {
    setState(() => _saving = true);
    try {
      final updated = await ref.read(profileRepositoryProvider).updateProfile(
            profile.copyWith(name: _name.text.trim()),
          );
      ref.read(vaultSessionProvider.notifier).setProfile(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Presets are bundled as `assets/avatars/1.png` … `60.png`.
  Future<void> _pickPreset(UserProfile profile) async {
    final colors = context.colors;
    final scale = Scale.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(scale.radiusLg)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.72,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(scale.md, scale.sm, scale.md, scale.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Choose avatar',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: scale.fontLg,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: AppIcon('close', color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.md),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: scale.sm,
                      crossAxisSpacing: scale.sm,
                    ),
                    itemCount: 60,
                    itemBuilder: (_, i) {
                      final id = '${i + 1}';
                      final isSelected =
                          profile.avatarType == AvatarType.preset &&
                              profile.avatarPresetId == id;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, id),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isSelected ? colors.primary : colors.border,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/avatars/$id.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: colors.primarySoft,
                                  alignment: Alignment.center,
                                  child: Text(
                                    id,
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    final updated = await ref.read(profileRepositoryProvider).updateProfile(
          profile.copyWith(
            avatarType: AvatarType.preset,
            avatarPresetId: selected,
            avatarPath: null,
          ),
        );
    ref.read(vaultSessionProvider.notifier).setProfile(updated);
  }

  /// Gallery pick is resized before upload to keep avatar objects small.
  Future<void> _uploadCustom(UserProfile profile) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _saving = true);
    try {
      final path = await ref.read(profileRepositoryProvider).uploadAvatar(
            userId: profile.id,
            filePath: file.path,
          );
      final updated = await ref.read(profileRepositoryProvider).updateProfile(
            profile.copyWith(
              avatarType: AvatarType.custom,
              avatarPath: path,
            ),
          );
      ref.read(vaultSessionProvider.notifier).setProfile(updated);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Compact outlined action matching Settings appearance chips (unselected).
class _AvatarAction extends StatelessWidget {
  const _AvatarAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(scale.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scale.radiusMd),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: scale.md,
            vertical: scale.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(scale.radiusMd),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
              fontSize: scale.fontSm,
            ),
          ),
        ),
      ),
    );
  }
}
