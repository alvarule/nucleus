/// New account: name + email only. Master password is set after email confirm.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/auth/presentation/providers/auth_controller.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final ok = await ref.read(authControllerProvider.notifier).requestSignupLink(
          name: name,
          email: email,
        );
    if (ok && mounted) {
      context.go(
        Uri(
          path: '/check-email',
          queryParameters: {'email': email, 'name': name},
        ).toString(),
      );
    }
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
                Text(
                  'We’ll email you a confirmation link. You’ll set your master password after you open it.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: scale.fontMd,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: scale.lg),
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
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                if (auth.error != null) ...[
                  SizedBox(height: scale.md),
                  Text(auth.error!, style: TextStyle(color: colors.danger)),
                ],
                SizedBox(height: scale.lg),
                PrimaryButton(
                  label: 'Send confirmation link',
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
