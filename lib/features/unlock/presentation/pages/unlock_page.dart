import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/di/providers.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';
import 'package:vaultify/shared/widgets/vault_text_field.dart';

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final can = await ref.read(biometricUnlockStoreProvider).canCheckBiometrics();
      final userId = ref.read(authRepositoryProvider).currentUserId;
      final hasDek = userId != null &&
          await ref.read(biometricUnlockStoreProvider).hasStoredDek(userId);
      if (mounted) setState(() => _bioAvailable = can && hasDek);
      if (_bioAvailable) {
        final ok =
            await ref.read(vaultSessionProvider.notifier).unlockWithBiometrics();
        if (ok && mounted) context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final session = ref.watch(vaultSessionProvider);

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
                style: TextStyle(color: colors.textSecondary, fontSize: scale.fontMd),
              ),
              SizedBox(height: scale.xl),
              if (_bioAvailable)
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await ref
                        .read(vaultSessionProvider.notifier)
                        .unlockWithBiometrics();
                    if (ok && context.mounted) context.go('/home');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    minimumSize: Size.fromHeight(scale.s(52)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(scale.radiusMd),
                    ),
                  ),
                  icon: AppIcon('fingerprint', color: colors.primary),
                  label: const Text('Unlock with fingerprint'),
                ),
              if (_bioAvailable) ...[
                SizedBox(height: scale.md),
                Row(
                  children: [
                    Expanded(child: Divider(color: colors.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: scale.sm),
                      child: Text('or', style: TextStyle(color: colors.textTertiary)),
                    ),
                    Expanded(child: Divider(color: colors.border)),
                  ],
                ),
                SizedBox(height: scale.md),
              ],
              VaultTextField(
                controller: _password,
                label: 'Master password',
                obscureText: _obscure,
                prefixIcon: 'lock',
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: AppIcon(
                    _obscure ? 'eye_off' : 'eye',
                    color: colors.textSecondary,
                  ),
                ),
              ),
              if (session.error != null) ...[
                SizedBox(height: scale.sm),
                Text(session.error!, style: TextStyle(color: colors.danger)),
              ],
              SizedBox(height: scale.lg),
              PrimaryButton(
                label: 'Continue',
                loading: session.status == VaultSessionStatus.unlocking,
                onPressed: () async {
                  await ref
                      .read(vaultSessionProvider.notifier)
                      .unlockWithPassword(_password.text);
                  if (ref.read(vaultSessionProvider).isUnlocked && context.mounted) {
                    context.go('/home');
                  }
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await ref.read(vaultSessionProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: Text('Sign out', style: TextStyle(color: colors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
