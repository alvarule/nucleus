/// Full sign-in second factor: TOTP or single-use backup code.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/auth/presentation/providers/pending_login_provider.dart';
import 'package:nucleus/features/mfa/data/login_mfa_service.dart';
import 'package:nucleus/features/mfa/domain/login_mfa_validation.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/mfa_otp_code_field.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class LoginTotpPage extends ConsumerStatefulWidget {
  const LoginTotpPage({super.key});

  @override
  ConsumerState<LoginTotpPage> createState() => _LoginTotpPageState();
}

class _LoginTotpPageState extends ConsumerState<LoginTotpPage> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _codeFieldError;
  bool _useBackup = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(pendingLoginPasswordProvider) == null && mounted) {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = ref.read(pendingLoginPasswordProvider);
    final profile = ref.read(vaultSessionProvider).profile;
    if (password == null || profile == null) {
      context.go('/login');
      return;
    }
    final fieldError = mfaSignInCodeFieldError(
      _code.text,
      backupMode: _useBackup,
    );
    if (fieldError != null) {
      setState(() => _codeFieldError = fieldError);
      return;
    }
    final submittedAtMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _loading = true;
      _error = null;
      _codeFieldError = null;
    });
    final service = LoginMfaService(ref.read(vaultCryptoProvider));
    final input = _code.text.trim();

    if (_useBackup || input.length > 6) {
      final result = await service.verifyAndConsumeBackupCode(
        masterPassword: password,
        profile: profile,
        code: input,
      );
      if (!result.ok) {
        setState(() {
          _loading = false;
          _error = 'Invalid or already used backup code';
        });
        return;
      }
      final updated = profile.copyWith(
        encryptedLoginBackupPayload: result.ciphertext,
        loginBackupPayloadNonce: result.nonce,
      );
      final saved = await ref.read(profileRepositoryProvider).updateProfile(updated);
      ref.read(vaultSessionProvider.notifier).setProfile(saved);
    } else {
      final ok = await service.verifyTotpCode(
        masterPassword: password,
        profile: profile,
        sixDigitCode: input,
        submittedAtMs: submittedAtMs,
      );
      if (!ok) {
        setState(() {
          _loading = false;
          _error = 'Invalid verification code';
        });
        return;
      }
    }

    await ref.read(vaultSessionProvider.notifier).clearSignInMfaRequired();
    await ref.read(vaultSessionProvider.notifier).unlockWithPassword(password);
    ref.read(pendingLoginPasswordProvider.notifier).state = null;
    if (!ref.read(vaultSessionProvider).isUnlocked) {
      setState(() {
        _loading = false;
        _error = 'Could not unlock vault';
      });
      return;
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify sign-in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(scale.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(scale.lg),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(scale.radiusLg),
                ),
                child: Column(
                  children: [
                    AppIcon('shield', size: scale.s(40), color: colors.primary),
                    SizedBox(height: scale.md),
                    Text(
                      _useBackup
                          ? 'Enter a backup recovery code'
                          : 'Enter the 6-digit code from your authenticator',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: scale.fontMd,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: scale.lg),
              if (_useBackup)
                VaultTextField(
                  controller: _code,
                  label: 'Backup code',
                  keyboardType: TextInputType.text,
                )
              else
                MfaOtpCodeField(
                  controller: _code,
                  errorText: _codeFieldError,
                  onCompleted: (_) => _submit(),
                ),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.only(top: scale.sm),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: scale.fontSm,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              SizedBox(height: scale.md),
              TextButton(
                onPressed: () {
                  setState(() {
                    _useBackup = !_useBackup;
                    _code.clear();
                    _error = null;
                    _codeFieldError = null;
                  });
                },
                child: Text(
                  _useBackup
                      ? 'Use authenticator code instead'
                      : 'Use a backup code instead',
                  style: TextStyle(color: colors.primary),
                ),
              ),
              SizedBox(height: scale.lg),
              PrimaryButton(
                label: 'Continue',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
