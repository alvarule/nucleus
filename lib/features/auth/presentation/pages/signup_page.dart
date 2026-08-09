import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/auth/presentation/providers/auth_controller.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';
import 'package:vaultify/shared/widgets/vault_text_field.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: AppIcon('back', color: colors.textPrimary),
        ),
        title: const Text('Create account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(scale.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VaultTextField(
                  controller: _name,
                  label: 'Name',
                  hint: 'Your name',
                  prefixIcon: 'user',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: scale.md),
                VaultTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'you@example.com',
                  prefixIcon: 'mail',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                SizedBox(height: scale.md),
                VaultTextField(
                  controller: _password,
                  label: 'Master password',
                  hint: 'Min 8 characters',
                  prefixIcon: 'lock',
                  obscureText: _obscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: AppIcon(
                      _obscure ? 'eye_off' : 'eye',
                      color: colors.textSecondary,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Min 8 characters' : null,
                ),
                SizedBox(height: scale.md),
                VaultTextField(
                  controller: _confirm,
                  label: 'Confirm master password',
                  obscureText: true,
                  prefixIcon: 'lock',
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
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final ok = await ref.read(authControllerProvider.notifier).signUp(
                          name: _name.text,
                          email: _email.text,
                          password: _password.text,
                        );
                    if (ok && context.mounted) context.go('/home');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
