/// Appearance, security timers, master-password change, lock, logout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';
import 'package:nucleus/features/settings/domain/security_timeouts.dart';
import 'package:nucleus/features/settings/presentation/providers/security_preference_provider.dart';
import 'package:nucleus/features/settings/presentation/providers/theme_preference_provider.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:nucleus/features/vault/presentation/widgets/vault_sync_dialogs.dart';
import 'package:nucleus/shared/widgets/app_buttons.dart';
import 'package:nucleus/shared/widgets/app_dialog.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/app_option_sheet.dart';
import 'package:nucleus/shared/widgets/ui_list_group.dart';

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
        padding: EdgeInsets.fromLTRB(scale.md, scale.sm, scale.md, scale.lg),
        children: [
          const UiSectionLabel('Appearance'),
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
          const UiSectionLabel('Sync'),
          if (profile != null)
            _SettingsRow(
              icon: 'device',
              title: 'Sync new items to cloud',
              subtitle: profile.defaultSyncMode == VaultSyncMode.cloud
                  ? 'New items upload by default'
                  : 'New items stay on this device',
              trailing: Switch.adaptive(
                value: profile.defaultSyncMode == VaultSyncMode.cloud,
                onChanged: (syncToCloud) => _onDefaultSyncToggle(
                  context,
                  ref,
                  profile,
                  syncToCloud,
                ),
                activeThumbColor: colors.onPrimary,
                activeTrackColor: colors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(scale.xs, scale.sm, scale.xs, 0),
            child: Text(
              'Local-only items are not backed up. Per-item sync can be changed when editing.',
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: scale.fontSm,
                height: 1.35,
              ),
            ),
          ),
          const UiSectionLabel('Security'),
          _SettingsRow(
            icon: 'shield',
            title: 'App Login MFA',
            subtitle: profile?.loginTotpEnabled == true
                ? 'On — required on full sign-in'
                : 'Off',
            onTap: () {
              if (profile?.loginTotpEnabled == true) {
                context.push('/settings/app-login-mfa');
              } else {
                context.push('/settings/app-login-mfa/setup');
              }
            },
          ),
          _SettingsRow(
            icon: 'timer',
            title: 'Auto-lock vault',
            subtitle: security.autoLock.label,
            onTap: () => _pickAutoLock(context, ref, security.autoLock),
          ),
          _SettingsRow(
            icon: 'eye',
            title: 'Re-auth for secrets',
            subtitle: security.revealGrace.label,
            onTap: () => _pickRevealGrace(context, ref, security.revealGrace),
          ),
          _SettingsRow(
            icon: 'timer',
            title: 'Password age threshold',
            subtitle: security.passwordAgeThreshold.label,
            onTap: () => _pickPasswordAgeThreshold(
              context,
              ref,
              security.passwordAgeThreshold,
            ),
          ),
          _SettingsRow(
            icon: 'lock',
            title: 'Change master password',
            subtitle: 'Vault stays encrypted',
            onTap: () => context.push('/settings/change-master-password'),
          ),
          _SettingsRow(
            icon: 'lock',
            title: 'Lock vault now',
            subtitle: 'Require master password to open',
            showDivider: false,
            onTap: () {
              ref.read(vaultSessionProvider.notifier).lock();
              context.go('/unlock');
            },
          ),
          SizedBox(height: scale.lg),
          Center(
            child: AppTextButton(
              label: 'Log out',
              destructive: true,
              onPressed: () => _confirmSignOut(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDefaultSyncToggle(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    bool syncToCloud,
  ) async {
    final selected =
        syncToCloud ? VaultSyncMode.cloud : VaultSyncMode.local;
    if (selected == profile.defaultSyncMode) return;
    final ok = await confirmGlobalSyncChange(
      context,
      from: profile.defaultSyncMode,
      to: selected,
    );
    if (ok != true || !context.mounted) return;

    BulkSyncChoice? bulkChoice;
    if (profile.defaultSyncMode == VaultSyncMode.local &&
        selected == VaultSyncMode.cloud) {
      bulkChoice = await confirmBulkUploadLocalItems(context);
    } else if (profile.defaultSyncMode == VaultSyncMode.cloud &&
        selected == VaultSyncMode.local) {
      bulkChoice = await confirmBulkDeleteCloudItems(context);
    }
    if (bulkChoice == null || !context.mounted) return;

    final updated = profile.copyWith(defaultSyncMode: selected);
    final saved =
        await ref.read(profileRepositoryProvider).updateProfile(updated);
    ref.read(vaultSessionProvider.notifier).setProfile(saved);

    if (bulkChoice != BulkSyncChoice.performBulk) return;

    final session = ref.read(vaultSessionProvider);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (!session.isUnlocked ||
        session.dek == null ||
        userId == null ||
        !context.mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final repo = ref.read(vaultRepositoryProvider);
      final result = selected == VaultSyncMode.cloud
          ? await repo.promoteAllLocalOnlyToCloud(
              userId: userId,
              dek: session.dek!,
            )
          : await repo.removeAllCloudItemsToLocal(
              userId: userId,
              dek: session.dek!,
            );
      await ref.read(vaultListProvider.notifier).refresh();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = result.hasFailures
          ? 'Default updated. ${result.succeeded} item(s) synced; ${result.failed} failed.'
          : 'Default updated. ${result.succeeded} item(s) synced.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final message = await userFacingErrorMessage(
          ref.read(connectivityServiceProvider),
          e,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Future<void> _setTheme(
    WidgetRef ref,
    UserProfile? profile,
    ThemePreference value,
  ) async {
    // Apply immediately, then persist so other devices pick it up from `profiles`.
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
    final selected = await showAppOptionSheet<VaultAutoLockOption>(
      context: context,
      title: 'Auto-lock vault',
      message: 'Locks after inactivity, including while the app is in the background.',
      selected: current,
      options: [
        for (final option in VaultAutoLockOption.values)
          AppSheetOption(
            value: option,
            title: option.label,
            subtitle: option.description,
          ),
      ],
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
    final selected = await showAppOptionSheet<RevealGraceOption>(
      context: context,
      title: 'Re-auth for secrets',
      message: 'How often reveal and copy ask for fingerprint or master password.',
      selected: current,
      options: [
        for (final option in RevealGraceOption.values)
          AppSheetOption(
            value: option,
            title: option.label,
            subtitle: option.description,
          ),
      ],
    );
    if (selected != null) {
      await ref
          .read(securityPreferenceProvider.notifier)
          .setRevealGrace(selected);
    }
  }

  Future<void> _pickPasswordAgeThreshold(
    BuildContext context,
    WidgetRef ref,
    PasswordAgeThresholdOption current,
  ) async {
    final selected = await showAppOptionSheet<PasswordAgeThresholdOption>(
      context: context,
      title: 'Password age threshold',
      message: 'Health flags passwords that have not been changed within this window.',
      selected: current,
      options: [
        for (final option in PasswordAgeThresholdOption.values)
          AppSheetOption(
            value: option,
            title: option.label,
            subtitle: option.description,
          ),
      ],
    );
    if (selected != null) {
      await ref
          .read(securityPreferenceProvider.notifier)
          .setPasswordAgeThreshold(selected);
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Log out?',
      message: 'You will need your master password to unlock again.',
      confirmLabel: 'Log out',
      tone: AppConfirmTone.destructive,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(vaultSessionProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}

/// List row matching Home / MFA: rose icon well on page background, hairline divider.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.showDivider = true,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(vertical: scale.xs),
          leading: Container(
            width: scale.s(44),
            height: scale.s(44),
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(scale.radiusSm),
            ),
            child: Center(
              child: AppIcon(icon, color: colors.primary),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: scale.fontLg,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: scale.fontSm,
                  ),
                ),
          trailing: trailing ??
              AppIcon('chevron_right', color: colors.textTertiary),
        ),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
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
          padding: EdgeInsets.symmetric(vertical: scale.sm, horizontal: scale.xs),
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
