/// First-time vault bootstrap after email confirmation. Sets master password.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/auth/presentation/providers/auth_controller.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class VaultSetupPage extends ConsumerStatefulWidget {
  const VaultSetupPage({super.key});

  @override
  ConsumerState<VaultSetupPage> createState() => _VaultSetupPageState();
}

class _VaultSetupPageState extends ConsumerState<VaultSetupPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .completeVaultSetup(masterPassword: _password.text);
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final auth = ref.watch(authControllerProvider);
    final repo = ref.watch(authRepositoryProvider);
    final email = repo.currentUserEmail ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create master password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(scale.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AppIcon('lock', size: scale.s(36), color: colors.primary),
                ),
                SizedBox(height: scale.md),
                Text(
                  'This password unlocks your vault and signs you in next time. It cannot be recovered.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: scale.fontMd,
                    height: 1.4,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  SizedBox(height: scale.md),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: scale.fontMd,
                    ),
                  ),
                ],
                SizedBox(height: scale.lg),
                VaultTextField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  label: 'Master password',
                  hint: 'Min 8 characters',
                  prefixIcon: 'lock',
                  obscureText: true,
                  enableObscureToggle: true,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Min 8 characters' : null,
                ),
                SizedBox(height: scale.md),
                VaultTextField(
                  controller: _confirm,
                  focusNode: _confirmFocus,
                  label: 'Confirm master password',
                  obscureText: true,
                  enableObscureToggle: true,
                  prefixIcon: 'lock',
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v != _password.text ? 'Passwords do not match' : null,
                ),
                if (auth.error != null) ...[
                  SizedBox(height: scale.md),
                  Text(auth.error!, style: TextStyle(color: colors.danger)),
                ],
                SizedBox(height: scale.lg),
                PrimaryButton(
                  label: 'Create vault',
                  loading: auth.loading,
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
