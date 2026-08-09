import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/settings/presentation/providers/change_master_password_controller.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';
import 'package:vaultify/shared/widgets/vault_text_field.dart';

class ChangeMasterPasswordPage extends ConsumerStatefulWidget {
  const ChangeMasterPasswordPage({super.key});

  @override
  ConsumerState<ChangeMasterPasswordPage> createState() =>
      _ChangeMasterPasswordPageState();
}

class _ChangeMasterPasswordPageState
    extends ConsumerState<ChangeMasterPasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _currentFocus = FocusNode();
  final _nextFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _currentFocus.dispose();
    _nextFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(changeMasterPasswordControllerProvider.notifier)
        .changeMasterPassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Master password updated. Vault items were not re-encrypted.'),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final form = ref.watch(changeMasterPasswordControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: form.loading ? null : () => context.pop(),
          icon: AppIcon('back', color: colors.textPrimary),
        ),
        title: const Text('Change master password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(scale.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Your vault stays encrypted the whole time. You're just updating the password that unlocks it.",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: scale.fontSm,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: scale.lg),
                VaultTextField(
                  controller: _current,
                  focusNode: _currentFocus,
                  label: 'Current master password',
                  prefixIcon: 'lock',
                  obscureText: true,
                  enableObscureToggle: true,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _nextFocus.requestFocus(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: scale.md),
                VaultTextField(
                  controller: _next,
                  focusNode: _nextFocus,
                  label: 'New master password',
                  hint: 'Min 8 characters',
                  prefixIcon: 'lock',
                  obscureText: true,
                  enableObscureToggle: true,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Min 8 characters';
                    }
                    if (v == _current.text) {
                      return 'Must differ from current password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: scale.md),
                VaultTextField(
                  controller: _confirm,
                  focusNode: _confirmFocus,
                  label: 'Confirm new master password',
                  prefixIcon: 'lock',
                  obscureText: true,
                  enableObscureToggle: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v != _next.text ? 'Passwords do not match' : null,
                ),
                if (form.error != null) ...[
                  SizedBox(height: scale.md),
                  Text(form.error!, style: TextStyle(color: colors.danger)),
                ],
                SizedBox(height: scale.lg),
                PrimaryButton(
                  label: 'Update master password',
                  loading: form.loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
