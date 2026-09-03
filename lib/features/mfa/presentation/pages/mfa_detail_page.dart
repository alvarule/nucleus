/// MFA entry detail with live code and countdown.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/mfa/data/login_mfa_service.dart';
import 'package:nucleus/features/mfa/domain/entities/mfa_entry.dart';
import 'package:nucleus/features/mfa/presentation/providers/mfa_list_provider.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/vault_loader.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

class MfaDetailPage extends ConsumerStatefulWidget {
  const MfaDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<MfaDetailPage> createState() => _MfaDetailPageState();
}

class _MfaDetailPageState extends ConsumerState<MfaDetailPage> {
  MfaEntry? _entry;
  Timer? _timer;
  String _code = '';
  int _secondsLeft = 30;
  final _accountController = TextEditingController();
  bool _accountDirty = false;
  bool _savingAccount = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _accountController.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    final entry = _entry;
    if (entry == null) return;
    final dirty = _accountController.text.trim() != entry.accountName;
    if (dirty != _accountDirty) {
      setState(() => _accountDirty = dirty);
    }
  }

  void _syncAccountField(MfaEntry entry) {
    _accountController.text = entry.accountName;
    _accountDirty = false;
  }

  Future<void> _load() async {
    final session = ref.read(vaultSessionProvider);
    final dek = session.dek;
    if (dek == null) return;
    final entry = await ref.read(mfaRepositoryProvider).getEntry(
          id: widget.entryId,
          dek: dek,
        );
    setState(() {
      _entry = entry;
      if (entry != null) _syncAccountField(entry);
    });
    _tick();
  }

  void _tick() {
    final entry = _entry;
    if (entry == null) return;
    final totp = LoginTotpService(ref.read(vaultCryptoProvider));
    _code = totp.generateCode(entry.secret);
    final now = DateTime.now().second;
    _secondsLeft = entry.period - (now % entry.period);
    setState(() {});
  }

  String _formattedCode(String raw) {
    if (raw.length == 6) {
      return '${raw.substring(0, 3)} ${raw.substring(3)}';
    }
    return raw;
  }

  Future<bool> _confirmDelete(MfaEntry entry) async {
    final colors = context.colors;
    final scale = Scale.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete authenticator?',
          style: TextStyle(fontSize: scale.fontXl, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove "${entry.displayTitle}"? This cannot be undone.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: scale.fontMd,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(fontSize: scale.fontMd)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: colors.danger,
                fontSize: scale.fontMd,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteEntry(MfaEntry entry) async {
    final ok = await _confirmDelete(entry);
    if (!ok || !mounted) return;
    try {
      await ref.read(mfaListProvider.notifier).delete(entry.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      return;
    }
    if (!mounted) return;
    context.pop();
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied')),
    );
  }

  Future<void> _saveAccount(MfaEntry entry) async {
    final session = ref.read(vaultSessionProvider);
    final dek = session.dek;
    if (dek == null) return;

    final accountName = _accountController.text.trim();
    setState(() => _savingAccount = true);
    try {
      final updated = await ref.read(mfaRepositoryProvider).updateEntry(
            entry: entry.copyWith(accountName: accountName),
            dek: dek,
          );
      ref.read(mfaListProvider.notifier).replaceEntry(updated);
      setState(() {
        _entry = updated;
        _accountDirty = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account updated')),
        );
      }
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
      if (mounted) setState(() => _savingAccount = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _accountController.removeListener(_onAccountChanged);
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final entry = _entry;
    if (entry == null) {
      return const VaultLoadingScaffold(message: 'Loading code…');
    }

    final period = entry.period > 0 ? entry.period : 30;
    final progress = (period - _secondsLeft) / period;

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.displayTitle),
        actions: [
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _deleteEntry(entry),
            icon: AppIcon('delete', color: colors.danger),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: scale.lg),
          child: Column(
            children: [
              SizedBox(height: scale.sm),
              Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(scale.radiusMd),
                child: Padding(
                  padding: EdgeInsets.all(scale.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VaultTextField(
                        controller: _accountController,
                        label: 'Account',
                        hint: 'Email or username',
                        prefixIcon: 'user',
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_accountDirty && !_savingAccount) {
                            _saveAccount(entry);
                          }
                        },
                      ),
                      if (_accountDirty) ...[
                        SizedBox(height: scale.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: _savingAccount
                                ? null
                                : () => _saveAccount(entry),
                            child: _savingAccount
                                ? VaultLoader(size: scale.s(28))
                                : const Text('Save account'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: scale.md),
              Expanded(
                child: Center(
                  child: Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(scale.radiusLg),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: scale.xl,
                        vertical: scale.xl,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: scale.s(72),
                            height: scale.s(72),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: scale.s(3),
                                  backgroundColor:
                                      colors.border.withValues(alpha: 0.5),
                                  color: colors.primary,
                                ),
                                Text(
                                  '$_secondsLeft',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: scale.fontLg,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: scale.lg),
                          Text(
                            _formattedCode(_code),
                            style: TextStyle(
                              fontSize: scale.s(40),
                              fontWeight: FontWeight.w800,
                              letterSpacing: scale.s(4),
                              color: colors.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          SizedBox(height: scale.xs),
                          Text(
                            'Verification code',
                            style: TextStyle(
                              color: colors.textTertiary,
                              fontSize: scale.fontSm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _copyCode,
                  icon: AppIcon('copy', color: colors.onPrimary, size: scale.iconSm),
                  label: const Text('Copy code'),
                ),
              ),
              SizedBox(height: scale.lg),
            ],
          ),
        ),
      ),
    );
  }
}
