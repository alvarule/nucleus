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
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
    if (ok && mounted) context.go('/home');
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
        title: const Text('Create Account'),
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
                  focusNode: _nameFocus,
                  label: 'Name',
                  hint: 'Your name',
                  prefixIcon: 'user',
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: scale.md),
                VaultTextField(
                  controller: _email,
                  focusNode: _emailFocus,
                  label: 'Email',
                  hint: 'you@example.com',
                  prefixIcon: 'mail',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                SizedBox(height: scale.md),
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
