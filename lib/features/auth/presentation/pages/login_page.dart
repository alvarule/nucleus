import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/auth/presentation/providers/auth_controller.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';
import 'package:vaultify/shared/widgets/vault_text_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).signIn(
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: scale.lg, vertical: scale.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: scale.xl),
                Center(
                  child: Container(
                    width: scale.s(72),
                    height: scale.s(72),
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(scale.radiusLg),
                      border: Border.all(color: colors.primary, width: 2),
                    ),
                    child: Center(
                      child: AppIcon('lock', size: scale.s(32), color: colors.primary),
                    ),
                  ),
                ),
                SizedBox(height: scale.md),
                Text(
                  'Vaultify',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: scale.fontHero,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: scale.xs),
                Text(
                  'Your vault, locked tight.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: scale.fontMd,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: scale.xl),
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
                  hint: 'Enter your master password',
                  prefixIcon: 'lock',
                  obscureText: true,
                  enableObscureToggle: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Min 8 characters' : null,
                ),
                if (auth.error != null) ...[
                  SizedBox(height: scale.md),
                  Text(
                    auth.error!,
                    style: TextStyle(color: colors.danger, fontSize: scale.fontSm),
                  ),
                ],
                SizedBox(height: scale.lg),
                PrimaryButton(
                  label: 'Unlock',
                  loading: auth.loading,
                  onPressed: _submit,
                ),
                SizedBox(height: scale.md),
                TextButton(
                  onPressed: () => context.push('/signup'),
                  child: Text(
                    'Create Account',
                    style: TextStyle(color: colors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
