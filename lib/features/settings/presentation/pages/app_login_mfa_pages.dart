/// App Login MFA: multi-step enable wizard and manage/disable flows.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/mfa/data/login_mfa_service.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/mfa_otp_code_field.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';
import 'package:nucleus/features/mfa/domain/login_mfa_validation.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// System save picker (same as attachment download), not the app documents dir.
Future<void> _saveBackupCodesWithPicker(
  BuildContext context,
  List<String> codes,
) async {
  final body = 'Nucleus App Login MFA backup codes\n\n${codes.join('\n')}\n';
  try {
    final uri = await FilePicker.saveFile(
      fileName: 'nucleus-login-backup-codes.txt',
      bytes: Uint8List.fromList(utf8.encode(body)),
      mimeType: 'text/plain',
    );
    if (uri == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File saved')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save file')),
    );
  }
}

class _MfaSectionHeader extends StatelessWidget {
  const _MfaSectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: scale.fontLg,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: scale.xs),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: scale.fontSm,
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _MfaInlineError extends StatelessWidget {
  const _MfaInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    return Padding(
      padding: EdgeInsets.only(top: scale.sm),
      child: Text(
        message,
        style: TextStyle(
          color: context.colors.danger,
          fontSize: scale.fontSm,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MfaMasterPasswordField extends StatelessWidget {
  const _MfaMasterPasswordField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return VaultTextField(
      controller: controller,
      label: 'Master password',
      obscureText: true,
      enableObscureToggle: true,
    );
  }
}

class _MfaAuthenticatorCodeField extends StatelessWidget {
  const _MfaAuthenticatorCodeField({
    required this.controller,
    this.label = 'Authenticator code',
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return MfaOtpCodeField(
      controller: controller,
      label: label,
      errorText: errorText,
    );
  }
}

class _MfaTextLink extends StatelessWidget {
  const _MfaTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        splashFactory: NoSplash.splashFactory,
      ),
      child: Text(label, style: TextStyle(color: colors.primary)),
    );
  }
}

class _BackupCodeActionRow extends StatelessWidget {
  const _BackupCodeActionRow({
    required this.onCopy,
    required this.onSaveFile,
  });

  final VoidCallback onCopy;
  final VoidCallback onSaveFile;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    return Row(
      children: [
        Expanded(
          child: _BackupCodeActionTile(
            icon: 'copy',
            label: 'Copy all',
            onTap: onCopy,
          ),
        ),
        SizedBox(width: scale.sm),
        Expanded(
          child: _BackupCodeActionTile(
            icon: 'note',
            label: 'Save file',
            onTap: onSaveFile,
          ),
        ),
      ],
    );
  }
}

class _BackupCodeActionTile extends StatelessWidget {
  const _BackupCodeActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return Material(
      color: colors.primarySoft,
      borderRadius: BorderRadius.circular(scale.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scale.radiusMd),
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: scale.md,
            horizontal: scale.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, color: colors.primary, size: scale.s(18)),
              SizedBox(width: scale.xs),
              Text(
                label,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: scale.fontSm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MfaEnableCta extends StatelessWidget {
  const _MfaEnableCta({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(scale.s(52)),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.border,
        disabledForegroundColor: colors.textTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scale.radiusMd),
        ),
        elevation: 0,
      ),
      child: loading
          ? SizedBox(
              height: scale.s(22),
              width: scale.s(22),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onPrimary,
              ),
            )
          : Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: scale.fontMd,
              ),
            ),
    );
  }
}

/// Settings entry when App Login MFA is off.
class AppLoginMfaSetupWizardPage extends ConsumerStatefulWidget {
  const AppLoginMfaSetupWizardPage({super.key});

  @override
  ConsumerState<AppLoginMfaSetupWizardPage> createState() =>
      _AppLoginMfaSetupWizardPageState();
}

class _AppLoginMfaSetupWizardPageState
    extends ConsumerState<AppLoginMfaSetupWizardPage> {
  int _step = 0;
  final _master = TextEditingController();
  final _verifyCode = TextEditingController();
  bool _loading = false;
  String? _masterFieldError;
  String? _codeFieldError;
  String? _secret;
  String? _otpAuthUri;
  bool _showManualKey = false;
  List<String>? _backupCodes;
  LoginBackupPayload? _backupPayload;
  bool _savedBackupAck = false;

  @override
  void dispose() {
    _master.dispose();
    _verifyCode.dispose();
    super.dispose();
  }

  Future<void> _confirmIdentity() async {
    final fieldError = mfaMasterPasswordFieldError(_master.text);
    if (fieldError != null) {
      setState(() {
        _masterFieldError = fieldError;
        _codeFieldError = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _masterFieldError = null;
      _codeFieldError = null;
    });
    final ok = await ref
        .read(vaultSessionProvider.notifier)
        .verifyMasterPassword(_master.text);
    if (!ok) {
      setState(() {
        _loading = false;
        _masterFieldError = 'Incorrect master password';
        _codeFieldError = null;
      });
      return;
    }
    final profile = ref.read(vaultSessionProvider).profile;
    final service = LoginMfaService(ref.read(vaultCryptoProvider));
    final secret = service.generateEnrollmentSecret();
  final uri = service.buildOtpAuthUri(
      email: profile?.email ?? 'user',
      secret: secret,
    );
    setState(() {
      _loading = false;
      _secret = secret;
      _otpAuthUri = uri;
      _step = 1;
    });
  }

  Future<void> _verifyAndBackup() async {
    final secret = _secret;
    if (secret == null) return;
    final codeError = mfaAuthenticatorCodeFieldError(_verifyCode.text);
    if (codeError != null) {
      setState(() {
        _codeFieldError = codeError;
        _masterFieldError = null;
      });
      return;
    }
    setState(() {
      _masterFieldError = null;
      _codeFieldError = null;
    });
    final service = LoginMfaService(ref.read(vaultCryptoProvider));
    if (!service.verifyPlaintextTotp(
      secret: secret,
      sixDigitCode: _verifyCode.text,
    )) {
      setState(() => _codeFieldError = 'Code does not match — check your authenticator');
      return;
    }
    final generated = service.generateBackupCodes();
    setState(() {
      _codeFieldError = null;
      _backupCodes = generated.codes;
      _backupPayload = generated.payload;
      _step = 2;
    });
  }

  Future<void> _finishEnable() async {
    if (!_savedBackupAck) return;
    final secret = _secret;
    final payload = _backupPayload;
    final profile = ref.read(vaultSessionProvider).profile;
    if (secret == null || payload == null || profile == null) return;
    setState(() => _loading = true);
    final service = LoginMfaService(ref.read(vaultCryptoProvider));
    try {
      final totpWrap = await service.wrapTotpSecret(
        masterPassword: _master.text,
        profile: profile,
        totpSecret: secret,
      );
      final backupWrap = await service.wrapBackupPayload(
        masterPassword: _master.text,
        profile: profile,
        payload: payload,
      );
      final updated = profile.copyWith(
        loginTotpEnabled: true,
        encryptedLoginTotpSecret: totpWrap.ciphertext,
        loginTotpSecretNonce: totpWrap.nonce,
        encryptedLoginBackupPayload: backupWrap.ciphertext,
        loginBackupPayloadNonce: backupWrap.nonce,
      );
      final saved =
          await ref.read(profileRepositoryProvider).updateProfile(updated);
      ref.read(vaultSessionProvider.notifier).setProfile(saved);
      if (mounted) {
        setState(() {
          _loading = false;
          _step = 3;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _codeFieldError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Login MFA'),
        leading: _step == 3
            ? null
            : IconButton(
                onPressed: () => context.pop(),
                icon: AppIcon('back', color: colors.textPrimary),
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(scale.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(step: _step, total: 4),
              SizedBox(height: scale.lg),
              Expanded(child: _buildStep(scale, colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(Scale scale, AppColors colors) {
    switch (_step) {
      case 0:
        return _IdentityStep(
          master: _master,
          loading: _loading,
          error: _masterFieldError,
          onContinue: _confirmIdentity,
        );
      case 1:
        return _EnrollStep(
          otpAuthUri: _otpAuthUri!,
          secret: _secret!,
          showManualKey: _showManualKey,
          verifyCode: _verifyCode,
          codeError: _codeFieldError,
          onToggleKey: () => setState(() => _showManualKey = !_showManualKey),
          onContinue: () {
            _verifyAndBackup();
          },
        );
      case 2:
        return _BackupStep(
          codes: _backupCodes!,
          ack: _savedBackupAck,
          onAck: (v) => setState(() => _savedBackupAck = v),
          onCopy: () => _copyCodes(_backupCodes!),
          onSaveFile: () => _saveCodesFile(_backupCodes!),
          loading: _loading,
          onFinish: _finishEnable,
        );
      case 3:
        return _SuccessStep(onDone: () => context.go('/settings'));
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _copyCodes(List<String> codes) async {
    await Clipboard.setData(ClipboardData(text: codes.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codes copied')),
      );
    }
  }

  Future<void> _saveCodesFile(List<String> codes) async {
    await _saveBackupCodesWithPicker(context, codes);
  }
}

class AppLoginMfaManagePage extends ConsumerStatefulWidget {
  const AppLoginMfaManagePage({super.key});

  @override
  ConsumerState<AppLoginMfaManagePage> createState() =>
      _AppLoginMfaManagePageState();
}

class _AppLoginMfaManagePageState extends ConsumerState<AppLoginMfaManagePage> {
  final _master = TextEditingController();
  final _code = TextEditingController();
  bool _loading = false;
  String? _masterFieldError;
  String? _codeFieldError;
  List<String>? _regeneratedCodes;

  void _clearFieldErrors() {
    _masterFieldError = null;
    _codeFieldError = null;
  }

  Future<void> _copyRegeneratedCodes() async {
    final codes = _regeneratedCodes;
    if (codes == null) return;
    await Clipboard.setData(ClipboardData(text: codes.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codes copied')),
      );
    }
  }

  Future<void> _saveRegeneratedCodesFile() async {
    final codes = _regeneratedCodes;
    if (codes == null) return;
    await _saveBackupCodesWithPicker(context, codes);
  }

  @override
  void dispose() {
    _master.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _disable() async {
    final profile = ref.read(vaultSessionProvider).profile;
    if (profile == null) return;
    final masterError = mfaMasterPasswordFieldError(_master.text);
    if (masterError != null) {
      setState(() {
        _masterFieldError = masterError;
        _codeFieldError = null;
      });
      return;
    }
    final codeError = mfaAuthenticatorCodeFieldError(_code.text);
    if (codeError != null) {
      setState(() {
        _codeFieldError = codeError;
        _masterFieldError = null;
      });
      return;
    }
    final submittedAtMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _loading = true;
      _clearFieldErrors();
    });
    final okMaster = await ref
        .read(vaultSessionProvider.notifier)
        .verifyMasterPassword(_master.text);
    if (!okMaster) {
      setState(() {
        _loading = false;
        _masterFieldError = 'Incorrect master password';
        _codeFieldError = null;
      });
      return;
    }
    final service = LoginMfaService(ref.read(vaultCryptoProvider));
    final totpOk = await service.verifyTotpCode(
      masterPassword: _master.text,
      profile: profile,
      sixDigitCode: _code.text.trim(),
      submittedAtMs: submittedAtMs,
    );
    if (!totpOk) {
      setState(() {
        _loading = false;
        _codeFieldError = 'Enter a valid authenticator code';
        _masterFieldError = null;
      });
      return;
    }
    final updated = profile.copyWith(
      loginTotpEnabled: false,
      clearLoginTotpSecret: true,
      clearLoginBackupPayload: true,
    );
    final saved = await ref.read(profileRepositoryProvider).updateProfile(updated);
    ref.read(vaultSessionProvider.notifier).setProfile(saved);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App Login MFA disabled. Backup codes are no longer valid.'),
        ),
      );
      context.pop();
    }
  }

  Future<void> _regenerateBackups() async {
    final profile = ref.read(vaultSessionProvider).profile;
    if (profile == null) return;
    final masterError = mfaMasterPasswordFieldError(_master.text);
    if (masterError != null) {
      setState(() {
        _masterFieldError = masterError;
        _codeFieldError = null;
      });
      return;
    }
    final codeError = mfaAuthenticatorCodeFieldError(_code.text);
    if (codeError != null) {
      setState(() {
        _codeFieldError = codeError;
        _masterFieldError = null;
      });
      return;
    }
    final submittedAtMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _loading = true;
      _clearFieldErrors();
    });
    final okMaster = await ref
        .read(vaultSessionProvider.notifier)
        .verifyMasterPassword(_master.text);
    if (!okMaster) {
      setState(() {
        _loading = false;
        _masterFieldError = 'Incorrect master password';
        _codeFieldError = null;
      });
      return;
    }
    final service = LoginMfaService(ref.read(vaultCryptoProvider));
    if (!await service.verifyTotpCode(
      masterPassword: _master.text,
      profile: profile,
      sixDigitCode: _code.text.trim(),
      submittedAtMs: submittedAtMs,
    )) {
      setState(() {
        _loading = false;
        _codeFieldError = 'Enter a valid authenticator code';
        _masterFieldError = null;
      });
      return;
    }
    final generated = service.generateBackupCodes();
    final backupWrap = await service.wrapBackupPayload(
      masterPassword: _master.text,
      profile: profile,
      payload: generated.payload,
    );
    final updated = profile.copyWith(
      encryptedLoginBackupPayload: backupWrap.ciphertext,
      loginBackupPayloadNonce: backupWrap.nonce,
    );
    final saved = await ref.read(profileRepositoryProvider).updateProfile(updated);
    ref.read(vaultSessionProvider.notifier).setProfile(saved);
    setState(() {
      _loading = false;
      _regeneratedCodes = generated.codes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final enabled = ref.watch(vaultSessionProvider).profile?.loginTotpEnabled;

    if (enabled != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('App Login MFA')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.replace('/settings/app-login-mfa/setup'),
            child: const Text('Set up App Login MFA'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Login MFA'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: AppIcon('back', color: colors.textPrimary),
        ),
      ),
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
                  border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    AppIcon('shield', color: colors.primary),
                    SizedBox(width: scale.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enabled == true ? 'Protection active' : 'Off',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: scale.fontLg,
                            ),
                          ),
                          Text(
                            'Required when signing in with email and master password. Unlock with biometric or password does not ask for MFA.',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: scale.fontSm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: scale.xl),
              Container(
                padding: EdgeInsets.all(scale.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(scale.radiusLg),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _MfaSectionHeader(
                      title: 'Regenerate backup codes',
                      subtitle:
                          'Creates a new set of one-time codes. Previous unused codes stop working.',
                    ),
                    SizedBox(height: scale.lg),
                    _MfaMasterPasswordField(controller: _master),
                    if (_masterFieldError != null)
                      _MfaInlineError(message: _masterFieldError!),
                    SizedBox(height: scale.md),
                    _MfaAuthenticatorCodeField(
                      controller: _code,
                      errorText: _codeFieldError,
                    ),
                    SizedBox(height: scale.lg),
                    FilledButton(
                      onPressed: _loading ? null : _regenerateBackups,
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(scale.s(48)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(scale.radiusMd),
                        ),
                      ),
                      child: const Text('Generate new backup codes'),
                    ),
                    if (_regeneratedCodes != null) ...[
                      SizedBox(height: scale.lg),
                      _BackupCodesCard(codes: _regeneratedCodes!),
                      SizedBox(height: scale.md),
                      _BackupCodeActionRow(
                        onCopy: _copyRegeneratedCodes,
                        onSaveFile: _saveRegeneratedCodesFile,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: scale.lg),
              Container(
                padding: EdgeInsets.all(scale.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(scale.radiusLg),
                  border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _MfaSectionHeader(
                      title: 'Disable App Login MFA',
                      subtitle:
                          'Uses the same master password and code fields above. Backup codes will be invalidated.',
                    ),
                    SizedBox(height: scale.lg),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _disable,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.danger,
                        side: BorderSide(color: colors.danger),
                        minimumSize: Size.fromHeight(scale.s(48)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(scale.radiusMd),
                        ),
                      ),
                      icon: AppIcon('shield', color: colors.danger, size: scale.s(20)),
                      label: const Text('Disable MFA'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return Row(
      children: List.generate(total, (i) {
        final active = i <= step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? scale.xs : 0),
            height: scale.s(4),
            decoration: BoxDecoration(
              color: active ? colors.primary : colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.master,
    required this.loading,
    required this.error,
    required this.onContinue,
  });

  final TextEditingController master;
  final bool loading;
  final String? error;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm your identity',
          style: TextStyle(
            fontSize: scale.fontXl,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: scale.sm),
        Text(
          'Enter your master password before we generate a login MFA secret.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: scale.fontMd,
            height: 1.35,
          ),
        ),
        SizedBox(height: scale.xl),
        _MfaMasterPasswordField(controller: master),
        if (error != null) _MfaInlineError(message: error!),
        const Spacer(),
        PrimaryButton(
          label: 'Continue',
          loading: loading,
          onPressed: onContinue,
        ),
      ],
    );
  }
}

class _SetupKeyCard extends StatelessWidget {
  const _SetupKeyCard({required this.secret});

  final String secret;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: colors.primarySoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(scale.radiusLg),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon('lock', color: colors.primary, size: scale.s(18)),
              SizedBox(width: scale.sm),
              Text(
                'Manual setup key',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: scale.fontSm,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: scale.md),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: scale.md,
              vertical: scale.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(scale.radiusMd),
              border: Border.all(color: colors.border),
            ),
            child: SelectableText(
              secret,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: scale.fontMd,
                letterSpacing: 1.4,
                color: colors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: scale.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: secret));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Setup key copied')),
                );
              },
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
              ),
              icon: AppIcon('copy', color: colors.primary, size: scale.s(18)),
              label: Text(
                'Copy key',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollStep extends StatelessWidget {
  const _EnrollStep({
    required this.otpAuthUri,
    required this.secret,
    required this.showManualKey,
    required this.verifyCode,
    required this.codeError,
    required this.onToggleKey,
    required this.onContinue,
  });

  final String otpAuthUri;
  final String secret;
  final bool showManualKey;
  final TextEditingController verifyCode;
  final String? codeError;
  final VoidCallback onToggleKey;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set up your authenticator',
            style: TextStyle(
              fontSize: scale.fontXl,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: scale.sm),
          Text(
            'Scan with Google Authenticator or a similar app on another device.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: scale.fontMd,
              height: 1.35,
            ),
          ),
          SizedBox(height: scale.lg),
          Center(
            child: Container(
              padding: EdgeInsets.all(scale.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(scale.radiusLg),
                border: Border.all(color: colors.border),
              ),
              child: QrImageView(
                data: otpAuthUri,
                size: scale.s(200),
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  color: Colors.black,
                ),
              ),
            ),
          ),
          SizedBox(height: scale.md),
          _MfaTextLink(
            label: showManualKey
                ? 'Hide setup key'
                : 'Can’t scan? Show setup key',
            onTap: onToggleKey,
          ),
          if (showManualKey) _SetupKeyCard(secret: secret),
          SizedBox(height: scale.lg),
          _MfaAuthenticatorCodeField(
            controller: verifyCode,
            label: 'Verify 6-digit code',
            errorText: codeError,
          ),
          SizedBox(height: scale.lg),
          PrimaryButton(label: 'Verify', onPressed: onContinue),
          SizedBox(height: scale.lg),
        ],
      ),
    );
  }
}

class _BackupStep extends StatelessWidget {
  const _BackupStep({
    required this.codes,
    required this.ack,
    required this.onAck,
    required this.onCopy,
    required this.onSaveFile,
    required this.loading,
    required this.onFinish,
  });

  final List<String> codes;
  final bool ack;
  final ValueChanged<bool> onAck;
  final VoidCallback onCopy;
  final VoidCallback onSaveFile;
  final bool loading;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Save your backup codes',
            style: TextStyle(
              fontSize: scale.fontXl,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: scale.sm),
          Text(
            'Each code works once if you lose your authenticator. You will not see these again — regenerate later if needed.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: scale.fontMd,
              height: 1.35,
            ),
          ),
          SizedBox(height: scale.lg),
          Container(
            padding: EdgeInsets.all(scale.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(scale.radiusLg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppIcon('shield', color: colors.primary, size: scale.s(20)),
                    SizedBox(width: scale.sm),
                    Text(
                      'Your recovery codes',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: scale.fontMd,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: scale.md),
                _BackupCodesCard(codes: codes),
                SizedBox(height: scale.md),
                _BackupCodeActionRow(
                  onCopy: onCopy,
                  onSaveFile: onSaveFile,
                ),
              ],
            ),
          ),
          SizedBox(height: scale.lg),
          Material(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(scale.radiusMd),
            child: CheckboxListTile(
              value: ack,
              onChanged: (v) => onAck(v ?? false),
              title: Text(
                'I’ve saved these codes somewhere safe',
                style: TextStyle(
                  fontSize: scale.fontMd,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              activeColor: colors.primary,
              checkColor: colors.onPrimary,
              contentPadding: EdgeInsets.symmetric(
                horizontal: scale.md,
                vertical: scale.xs,
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          SizedBox(height: scale.lg),
          _MfaEnableCta(
            label: 'Turn on App Login MFA',
            loading: loading,
            onPressed: ack ? onFinish : null,
          ),
          SizedBox(height: scale.lg),
        ],
      ),
    );
  }
}

class _BackupCodesCard extends StatelessWidget {
  const _BackupCodesCard({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: colors.primarySoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(scale.radiusMd),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoCol = constraints.maxWidth > scale.s(280);
          if (!twoCol) {
            return Column(
              children: codes
                  .map((c) => _BackupCodeLine(code: c))
                  .toList(),
            );
          }
          return Wrap(
            spacing: scale.sm,
            runSpacing: scale.xs,
            children: codes
                .map(
                  (c) => SizedBox(
                    width: (constraints.maxWidth - scale.sm) / 2,
                    child: _BackupCodeLine(code: c),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _BackupCodeLine extends StatelessWidget {
  const _BackupCodeLine({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: scale.xs),
      child: Text(
        code,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: scale.fontMd,
          letterSpacing: 1.5,
          color: colors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return Column(
      children: [
        const Spacer(),
        AppIcon('shield', size: scale.s(64), color: colors.primary),
        SizedBox(height: scale.lg),
        Text(
          'App Login MFA is on',
          style: TextStyle(
            fontSize: scale.fontXl,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: scale.sm),
        Text(
          'You’ll verify on full sign-in. Unlocking the app stays biometric or master password only.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary),
        ),
        const Spacer(),
        PrimaryButton(label: 'Done', onPressed: onDone),
      ],
    );
  }
}
