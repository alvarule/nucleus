import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

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

  final confirmed = await showMasterPasswordSheet(
    context,
    title: 'Confirm master password',
    actionLabel: 'Confirm',
    verify: (password) => ref
        .read(vaultSessionProvider.notifier)
        .confirmMasterPasswordForReveal(password),
  );
  return confirmed == true;
}

Future<bool?> showMasterPasswordSheet(
  BuildContext context, {
  String title = 'Confirm master password',
  String actionLabel = 'Confirm',
  required Future<bool> Function(String password) verify,
}) {
  final colors = context.colors;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    builder: (ctx) => _MasterPasswordSheetBody(
      title: title,
      actionLabel: actionLabel,
      verify: verify,
    ),
  );
}

class _MasterPasswordSheetBody extends StatefulWidget {
  const _MasterPasswordSheetBody({
    required this.title,
    required this.actionLabel,
    required this.verify,
  });

  final String title;
  final String actionLabel;
  final Future<bool> Function(String password) verify;

  @override
  State<_MasterPasswordSheetBody> createState() =>
      _MasterPasswordSheetBodyState();
}

class _MasterPasswordSheetBodyState extends State<_MasterPasswordSheetBody> {
  late final TextEditingController _controller;
  String? _error;
  bool _verifying = false;

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

  Future<void> _submit() async {
    if (_verifying) return;
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your master password');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    final ok = await widget.verify(password);
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _verifying = false;
      _error = 'Wrong master password';
    });
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
            onFieldSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: colors.danger, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: widget.actionLabel,
            loading: _verifying,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
