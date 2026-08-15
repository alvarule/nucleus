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
  final _nameFocus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(vaultSessionProvider).profile;
    _name = TextEditingController(text: profile?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
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
      ),
      body: ListView(
        padding: EdgeInsets.all(scale.lg),
        children: [
          Center(
            child: Hero(tag: 'profile_avatar', child: AvatarWidget(profile: profile, size: scale.s(96))),
          ),
          SizedBox(height: scale.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _pickPreset(profile),
                child: Text('Choose avatar', style: TextStyle(color: colors.primary)),
              ),
              TextButton(
                onPressed: () => _uploadCustom(profile),
                child: Text('Upload photo', style: TextStyle(color: colors.primary)),
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
            controller: TextEditingController(text: profile.email),
            label: 'Email',
            prefixIcon: 'mail',
            // Auth identity; changing email is not implemented.
            enabled: false,
          ),
          SizedBox(height: scale.lg),
          PrimaryButton(
            label: 'Save profile',
            loading: _saving,
            onPressed: () => _save(profile),
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
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.75,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Choose avatar',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
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
