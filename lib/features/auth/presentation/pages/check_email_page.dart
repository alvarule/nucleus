/// Shown after signup until the user opens the confirmation email.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/auth/presentation/providers/auth_controller.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class CheckEmailPage extends ConsumerWidget {
  const CheckEmailPage({
    super.key,
    required this.email,
    required this.name,
  });

  final String email;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/signup'),
          icon: AppIcon('back', color: colors.textPrimary),
        ),
        title: const Text('Check your email'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(scale.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: scale.s(72),
                  height: scale.s(72),
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(scale.radiusLg),
                  ),
                  child: Center(
                    child: AppIcon('mail', size: scale.s(32), color: colors.primary),
                  ),
                ),
              ),
              SizedBox(height: scale.lg),
              Text(
                'We sent a confirmation link to',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: scale.fontMd,
                ),
              ),
              SizedBox(height: scale.sm),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: scale.fontLg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: scale.md),
              Text(
                'Open the link on this device to continue. You can go back if you need to use a different email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: scale.fontMd,
                  height: 1.4,
                ),
              ),
              if (auth.error != null) ...[
                SizedBox(height: scale.md),
                Text(
                  auth.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.danger, fontSize: scale.fontSm),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Resend confirmation email',
                loading: auth.loading,
                onPressed: () async {
                  final ok = await ref
                      .read(authControllerProvider.notifier)
                      .resendSignupLink(name: name, email: email);
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Confirmation email sent')),
                    );
                  }
                },
              ),
              SizedBox(height: scale.sm),
              TextButton(
                onPressed: () => context.go('/signup'),
                child: Text(
                  'Use a different email',
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
