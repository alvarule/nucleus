import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/di/providers.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/profile/domain/entities/user_profile.dart';
import 'package:vaultify/features/settings/domain/security_timeouts.dart';
import 'package:vaultify/features/settings/presentation/providers/security_preference_provider.dart';
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
    final security = ref.watch(securityPreferenceProvider);
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
          Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  label: 'System',
                  icon: 'device',
                  selected: themePref == ThemePreference.system,
                  onTap: () => _setTheme(ref, profile, ThemePreference.system),
                ),
              ),
              SizedBox(width: scale.sm),
              Expanded(
                child: _ThemeOption(
                  label: 'Light',
                  icon: 'sun',
                  selected: themePref == ThemePreference.light,
                  onTap: () => _setTheme(ref, profile, ThemePreference.light),
                ),
              ),
              SizedBox(width: scale.sm),
              Expanded(
                child: _ThemeOption(
                  label: 'Dark',
                  icon: 'moon',
                  selected: themePref == ThemePreference.dark,
                  onTap: () => _setTheme(ref, profile, ThemePreference.dark),
                ),
              ),
            ],
          ),
          SizedBox(height: scale.xl),
          Text(
            'Security',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: scale.fontSm,
            ),
          ),
          SizedBox(height: scale.sm),
          _SecurityTile(
            icon: 'timer',
            title: 'Auto-lock vault',
            subtitle: security.autoLock.label,
            onTap: () => _pickAutoLock(context, ref, security.autoLock),
          ),
          _SecurityTile(
            icon: 'eye',
            title: 'Re-auth for secrets',
            subtitle: security.revealGrace.label,
            onTap: () => _pickRevealGrace(context, ref, security.revealGrace),
          ),
          SizedBox(height: scale.md),
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
            label: 'Sign Out',
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _setTheme(
    WidgetRef ref,
    UserProfile? profile,
    ThemePreference value,
  ) async {
    ref.read(themePreferenceProvider.notifier).setLocal(value);
    if (profile != null) {
      final updated = await ref
          .read(profileRepositoryProvider)
          .updateProfile(profile.copyWith(themePreference: value));
      ref.read(vaultSessionProvider.notifier).setProfile(updated);
    }
  }

  Future<void> _pickAutoLock(
    BuildContext context,
    WidgetRef ref,
    VaultAutoLockOption current,
  ) async {
    final colors = context.colors;
    final selected = await showModalBottomSheet<VaultAutoLockOption>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Auto-lock vault',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Locks after inactivity. The vault still locks when the app goes to background.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ),
              ...VaultAutoLockOption.values.map(
                (option) => ListTile(
                  title: Text(option.label),
                  subtitle: Text(option.description),
                  trailing: option == current
                      ? AppIcon('check', color: colors.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, option),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await ref.read(securityPreferenceProvider.notifier).setAutoLock(selected);
    }
  }

  Future<void> _pickRevealGrace(
    BuildContext context,
    WidgetRef ref,
    RevealGraceOption current,
  ) async {
    final colors = context.colors;
    final selected = await showModalBottomSheet<RevealGraceOption>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Re-auth for secrets',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Controls how often reveal and copy ask for fingerprint or master password.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ),
              ...RevealGraceOption.values.map(
                (option) => ListTile(
                  title: Text(option.label),
                  subtitle: Text(option.description),
                  trailing: option == current
                      ? AppIcon('check', color: colors.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, option),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await ref
          .read(securityPreferenceProvider.notifier)
          .setRevealGrace(selected);
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'You will need your master password to unlock again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(vaultSessionProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIcon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.textSecondary),
      ),
      trailing: AppIcon('chevron_right', color: colors.textTertiary),
      onTap: onTap,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);

    return Material(
      color: selected ? colors.primarySoft : colors.surface,
      borderRadius: BorderRadius.circular(scale.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scale.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: scale.md, horizontal: scale.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(scale.radiusMd),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              AppIcon(
                icon,
                color: selected ? colors.primary : colors.textSecondary,
              ),
              SizedBox(height: scale.xs),
              Text(
                label,
                style: TextStyle(
                  color: selected ? colors.primary : colors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: scale.fontSm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
