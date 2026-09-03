/// Manual MFA entry (issuer, account, secret).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/mfa/presentation/providers/mfa_list_provider.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/shared/widgets/vault_loader.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class MfaNewPage extends ConsumerStatefulWidget {
  const MfaNewPage({
    super.key,
    this.initialSecret,
    this.initialIssuer,
    this.initialAccount,
    this.vaultItemId,
  });

  final String? initialSecret;
  final String? initialIssuer;
  final String? initialAccount;
  final String? vaultItemId;

  @override
  ConsumerState<MfaNewPage> createState() => _MfaNewPageState();
}

class _MfaNewPageState extends ConsumerState<MfaNewPage> {
  final _formKey = GlobalKey<FormState>();
  final _issuer = TextEditingController();
  final _account = TextEditingController();
  final _secret = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSecret != null) {
      _secret.text = widget.initialSecret!;
    }
    if (widget.initialIssuer != null) {
      _issuer.text = widget.initialIssuer!;
    }
    if (widget.initialAccount != null) {
      _account.text = widget.initialAccount!;
    }
  }

  @override
  void dispose() {
    _issuer.dispose();
    _account.dispose();
    _secret.dispose();
    super.dispose();
  }

  String? _requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final session = ref.read(vaultSessionProvider);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    final dek = session.dek;
    if (dek == null || userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(mfaRepositoryProvider).createEntry(
            userId: userId,
            dek: dek,
            secret: _secret.text.trim(),
            issuer: _issuer.text.trim(),
            accountName: _account.text.trim(),
            vaultItemId: widget.vaultItemId,
          );
      await ref.read(mfaListProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      final message = await userFacingErrorMessage(
        ref.read(connectivityServiceProvider),
        e,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Add authenticator')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(scale.lg),
          children: [
            Text(
              'Enter the site name and secret from your authenticator app, or scan a QR code.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: scale.fontMd,
              ),
            ),
            SizedBox(height: scale.lg),
            Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(scale.radiusMd),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.all(scale.md),
                child: Column(
                  children: [
                    VaultTextField(
                      controller: _issuer,
                      label: 'Issuer',
                      hint: 'e.g. GitHub',
                      prefixIcon: 'shield',
                      textInputAction: TextInputAction.next,
                      validator: (v) => _requiredField(v, 'Issuer'),
                    ),
                    SizedBox(height: scale.md),
                    VaultTextField(
                      controller: _account,
                      label: 'Account',
                      hint: 'Email or username (optional)',
                      prefixIcon: 'user',
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: scale.md),
                    VaultTextField(
                      controller: _secret,
                      label: 'Secret key',
                      hint: 'Base32 secret',
                      prefixIcon: 'lock',
                      obscureText: true,
                      enableObscureToggle: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      validator: (v) => _requiredField(v, 'Secret key'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: scale.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? VaultLoader(size: scale.s(28))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
