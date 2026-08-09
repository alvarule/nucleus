import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/di/providers.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/profile/domain/entities/user_profile.dart';
import 'package:vaultify/features/settings/presentation/providers/theme_preference_provider.dart';
import 'package:vaultify/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';
import 'package:vaultify/shared/widgets/vault_text_field.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final themePref = ref.watch(themePreferenceProvider);
    final profile = ref.watch(vaultSessionProvider).profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(scale.lg),
        children: [
          Text(
            'Appearance',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: scale.fontSm,
            ),
          ),
          SizedBox(height: scale.sm),
          SegmentedButton<ThemePreference>(
            segments: const [
              ButtonSegment(value: ThemePreference.system, label: Text('System')),
              ButtonSegment(value: ThemePreference.light, label: Text('Light')),
              ButtonSegment(value: ThemePreference.dark, label: Text('Dark')),
            ],
            selected: {themePref},
            onSelectionChanged: (set) async {
              final value = set.first;
              ref.read(themePreferenceProvider.notifier).setLocal(value);
              if (profile != null) {
                final updated = await ref
                    .read(profileRepositoryProvider)
                    .updateProfile(profile.copyWith(themePreference: value));
                ref.read(vaultSessionProvider.notifier).setProfile(updated);
              }
            },
          ),
          SizedBox(height: scale.xl),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppIcon('user', color: colors.primary),
            title: const Text('Profile'),
            trailing: AppIcon('chevron_right', color: colors.textTertiary),
            onTap: () => context.push('/profile'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppIcon('lock', color: colors.primary),
            title: const Text('Lock vault now'),
            onTap: () {
              ref.read(vaultSessionProvider.notifier).lock();
              context.go('/unlock');
            },
          ),
          SizedBox(height: scale.lg),
          PrimaryButton(
            label: 'Sign out',
            onPressed: () async {
              await ref.read(vaultSessionProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
