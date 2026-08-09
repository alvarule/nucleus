import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:vaultify/shared/widgets/vault_text_field.dart';

/// Ensures the user passed biometric or master-password gate for sensitive actions.
Future<bool> ensureSensitiveAccess(
  BuildContext context,
  WidgetRef ref, {
  String biometricReason = 'Confirm to continue',
}) async {
  final session = ref.read(vaultSessionProvider);
  if (session.canRevealSecrets) return true;

  final bioOk = await ref
      .read(vaultSessionProvider.notifier)
      .gateForReveal(reason: biometricReason);
  if (bioOk) return true;
  if (!context.mounted) return false;

  final password = await showMasterPasswordSheet(
    context,
    title: 'Confirm master password',
    actionLabel: 'Confirm',
  );
  if (password == null || password.isEmpty) return false;

  await ref.read(vaultSessionProvider.notifier).unlockWithPassword(password);
  if (!ref.read(vaultSessionProvider).isUnlocked) return false;
  ref.read(vaultSessionProvider.notifier).grantRevealGrace();
  return true;
}

Future<String?> showMasterPasswordSheet(
  BuildContext context, {
  String title = 'Confirm master password',
  String actionLabel = 'Confirm',
}) {
  final controller = TextEditingController();
  final colors = context.colors;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            VaultTextField(
              controller: controller,
              obscureText: true,
              enableObscureToggle: true,
              prefixIcon: 'lock',
              hint: 'Master password',
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: actionLabel,
              onPressed: () => Navigator.pop(ctx, controller.text),
            ),
          ],
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
