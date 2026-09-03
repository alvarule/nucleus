/// Post-auth vault gate: biometrics if a DEK is cached, otherwise master password.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/shared/widgets/app_dialog.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/app_buttons.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _bioAvailable = false;
  bool _bioPrompted = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_prepareBiometrics);
  }

  /// Auto-prompts biometrics once per visit when a stored DEK exists.
  Future<void> _prepareBiometrics() async {
    final session = ref.read(vaultSessionProvider);
    if (session.signInMfaPending) {
      if (mounted) setState(() => _bioAvailable = false);
      return;
    }
    final can = await ref
        .read(biometricUnlockStoreProvider)
        .canCheckBiometrics();
    final userId = ref.read(authRepositoryProvider).currentUserId;
    final hasDek =
        userId != null &&
        await ref.read(biometricUnlockStoreProvider).hasStoredDek(userId);
    if (!mounted) return;
    setState(() => _bioAvailable = can && hasDek);
    if (_bioAvailable && !_bioPrompted) {
      _bioPrompted = true;
      await _unlockWithBiometrics();
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final ok = await ref
        .read(vaultSessionProvider.notifier)
        .unlockWithBiometrics();
    if (ok && mounted) context.go('/home');
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Log out?',
      message: 'You will need your master password to unlock again.',
      confirmLabel: 'Log out',
      tone: AppConfirmTone.destructive,
    );
    if (!confirmed || !mounted) return;
    await ref.read(vaultSessionProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final session = ref.watch(vaultSessionProvider);
    final profile = ref.watch(vaultSessionProvider).profile;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(scale.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: scale.s(88),
                  height: scale.s(88),
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AppIcon(
                      'fingerprint',
                      size: scale.s(40),
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(height: scale.lg),
              Text(
                'Unlock vault',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: scale.fontXl,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: scale.xs),
              Text(
                'Use fingerprint or master password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: scale.fontMd,
                ),
              ),
              SizedBox(height: scale.xl),
              if (_bioAvailable)
                SecondaryButton(
                  label: 'Unlock with fingerprint',
                  icon: 'fingerprint',
                  onPressed: _unlockWithBiometrics,
                ),
              if (_bioAvailable) ...[
                SizedBox(height: scale.md),
                Row(
                  children: [
                    Expanded(child: Divider(color: colors.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: scale.sm),
                      child: Text(
                        'or',
                        style: TextStyle(color: colors.textTertiary),
                      ),
                    ),
                    Expanded(child: Divider(color: colors.border)),
                  ],
                ),
                SizedBox(height: scale.md),
              ],
              VaultTextField(
                controller: _password,
                focusNode: _passwordFocus,
                label: 'Master password',
                obscureText: true,
                enableObscureToggle: true,
                prefixIcon: 'lock',
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitPassword(),
              ),
              if (session.error != null) ...[
                SizedBox(height: scale.sm),
                Text(session.error!, style: TextStyle(color: colors.danger)),
              ],
              SizedBox(height: scale.lg),
              PrimaryButton(
                label: 'Unlock',
                loading: session.status == VaultSessionStatus.unlocking,
                onPressed: _submitPassword,
              ),
              const Spacer(),
              Text(
                profile!.email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: scale.fontMd,
                ),
              ),
              Center(
                child: AppTextButton(
                  label: 'Log out',
                  destructive: true,
                  onPressed: _confirmSignOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitPassword() async {
    await ref
        .read(vaultSessionProvider.notifier)
        .unlockWithPassword(_password.text);
    if (ref.read(vaultSessionProvider).isUnlocked && mounted) {
      context.go('/home');
    }
  }
}
