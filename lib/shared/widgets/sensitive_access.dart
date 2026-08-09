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

  // Verify password without flipping session to unlocking (avoids /unlock redirect).
  return ref
      .read(vaultSessionProvider.notifier)
      .confirmMasterPasswordForReveal(password);
}

Future<String?> showMasterPasswordSheet(
  BuildContext context, {
  String title = 'Confirm master password',
  String actionLabel = 'Confirm',
}) {
  final colors = context.colors;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    builder: (ctx) => _MasterPasswordSheetBody(
      title: title,
      actionLabel: actionLabel,
    ),
  );
}

class _MasterPasswordSheetBody extends StatefulWidget {
  const _MasterPasswordSheetBody({
    required this.title,
    required this.actionLabel,
  });

  final String title;
  final String actionLabel;

  @override
  State<_MasterPasswordSheetBody> createState() =>
      _MasterPasswordSheetBodyState();
}

class _MasterPasswordSheetBodyState extends State<_MasterPasswordSheetBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: viewInsets + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          VaultTextField(
            controller: _controller,
            obscureText: true,
            enableObscureToggle: true,
            prefixIcon: 'lock',
            hint: 'Master password',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: widget.actionLabel,
            onPressed: () => Navigator.pop(context, _controller.text),
          ),
        ],
      ),
    );
  }
}
