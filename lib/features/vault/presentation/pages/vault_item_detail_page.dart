import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vaultify/core/di/providers.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:vaultify/features/vault/domain/entities/vault_item.dart';
import 'package:vaultify/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';
import 'package:vaultify/shared/widgets/masked_secret_field.dart';
import 'package:vaultify/shared/widgets/vault_loader.dart';
import 'package:vaultify/shared/widgets/vault_text_field.dart';

class VaultItemDetailPage extends ConsumerStatefulWidget {
  const VaultItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<VaultItemDetailPage> createState() => _VaultItemDetailPageState();
}

class _VaultItemDetailPageState extends ConsumerState<VaultItemDetailPage> {
  VaultItem? _item;
  bool _loading = true;
  final _revealed = <String>{};
  String? _error;

  static const _sensitiveKeys = {
    'password',
    'account_no',
    'cvv',
    'atm_pin',
    'upi_pin',
    'card_no',
    'ifsc',
    'micr',
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final dek = ref.read(vaultSessionProvider).dek;
    if (dek == null) {
      setState(() {
        _loading = false;
        _error = 'Vault locked';
      });
      return;
    }
    try {
      final item = await ref.read(vaultRepositoryProvider).getItem(
            id: widget.itemId,
            dek: dek,
          );
      setState(() {
        _item = item;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleReveal(String key) async {
    if (_revealed.contains(key)) {
      setState(() => _revealed.remove(key));
      return;
    }
    final session = ref.read(vaultSessionProvider);
    if (session.canRevealSecrets) {
      setState(() => _revealed.add(key));
      return;
    }
    final bioOk = await ref.read(vaultSessionProvider.notifier).gateForReveal();
    if (bioOk) {
      setState(() => _revealed.add(key));
      return;
    }
    if (!mounted) return;
    final password = await _askMasterPassword();
    if (password == null || password.isEmpty) return;
    await ref.read(vaultSessionProvider.notifier).unlockWithPassword(password);
    if (ref.read(vaultSessionProvider).isUnlocked) {
      ref.read(vaultSessionProvider.notifier).grantRevealGrace();
      setState(() => _revealed.add(key));
    }
  }

  Future<String?> _askMasterPassword() async {
    final controller = TextEditingController();
    final colors = context.colors;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confirm master password',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              VaultTextField(
                controller: controller,
                obscureText: true,
                prefixIcon: 'lock',
                hint: 'Master password',
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Reveal',
                onPressed: () => Navigator.pop(ctx, controller.text),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final dateFormat = DateFormat.yMMMd().add_jm();

    if (_loading) return const VaultLoadingScaffold();
    if (_error != null || _item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Not found')),
      );
    }

    final item = _item!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: AppIcon('back', color: colors.textPrimary),
        ),
        title: Text(item.label),
        actions: [
          IconButton(
            onPressed: () => context.push(
              '/vault/edit/${item.id}',
              extra: item,
            ),
            icon: AppIcon('settings', color: colors.textSecondary),
          ),
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete item?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Delete', style: TextStyle(color: colors.danger)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(vaultListProvider.notifier).delete(item.id);
                if (context.mounted) context.go('/home');
              }
            },
            icon: AppIcon('lock', color: colors.danger),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(scale.lg),
        children: [
          ...item.fields.entries.where((e) => '${e.value}'.isNotEmpty).map((e) {
            final key = e.key;
            final value = '${e.value}';
            if (_sensitiveKeys.contains(key)) {
              return Padding(
                padding: EdgeInsets.only(bottom: scale.md),
                child: MaskedSecretField(
                  label: key.replaceAll('_', ' '),
                  value: value,
                  revealed: _revealed.contains(key),
                  onToggle: () => _toggleReveal(key),
                ),
              );
            }
            return Padding(
              padding: EdgeInsets.only(bottom: scale.md),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(scale.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(scale.radiusMd),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key.replaceAll('_', ' '),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: scale.fontSm,
                      ),
                    ),
                    SizedBox(height: scale.xs),
                    Text(
                      value,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: scale.fontLg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: scale.md),
          Text(
            'Created ${dateFormat.format(item.createdAt)}',
            style: TextStyle(color: colors.textTertiary, fontSize: scale.fontSm),
          ),
          Text(
            'Updated ${dateFormat.format(item.updatedAt)}',
            style: TextStyle(color: colors.textTertiary, fontSize: scale.fontSm),
          ),
        ],
      ),
    );
  }
}
