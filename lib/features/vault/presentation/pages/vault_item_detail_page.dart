/// Decrypts one item by id and shows fields; secrets stay masked until gated.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/health/domain/entities/item_health_snapshot.dart';
import 'package:nucleus/features/health/presentation/providers/password_health_provider.dart';
import 'package:nucleus/features/health/presentation/widgets/health_badge.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/password_field_helpers.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/masked_secret_field.dart';
import 'package:nucleus/shared/widgets/sensitive_access.dart';
import 'package:nucleus/shared/widgets/vault_loader.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart';

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

  /// Keys shown behind [MaskedSecretField] rather than plaintext.
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
    final ok = await ensureSensitiveAccess(
      context,
      ref,
      biometricReason: 'Reveal sensitive data',
    );
    if (ok && mounted) setState(() => _revealed.add(key));
  }

  Future<void> _copySecret(String key, String value) async {
    final ok = await ensureSensitiveAccess(
      context,
      ref,
      biometricReason: 'Confirm to copy',
    );
    if (!ok || !mounted) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${titleCaseLabel(key)} copied')),
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
    final navigatorCanPop = Navigator.of(context).canPop();
    final healthSnapshot = item.type == VaultItemType.password
        ? ref.watch(passwordHealthProvider).forItem(item.id)
        : null;

    return PopScope(
      canPop: navigatorCanPop,
      onPopInvokedWithResult: (didPop, _) {
        // If this route is the only one (deep link / stack wipe), go Home.
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            icon: AppIcon('back', color: colors.textPrimary),
          ),
          title: Text(
            item.label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: scale.fontXl,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Edit',
              onPressed: () => context.push(
                '/vault/edit/${item.id}',
                extra: item,
              ),
              icon: AppIcon('edit', color: colors.textSecondary),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      'Delete item?',
                      style: TextStyle(fontSize: scale.fontXl),
                    ),
                    content: Text(
                      'This cannot be undone.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: scale.fontMd,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Delete',
                          style: TextStyle(color: colors.danger),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(vaultListProvider.notifier).delete(item.id);
                  if (context.mounted) context.go('/home');
                }
              },
              icon: AppIcon('delete', color: colors.danger),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.all(scale.lg),
          children: [
            if (healthSnapshot != null) ...[
              Row(
                children: [
                  HealthBadge(snapshot: healthSnapshot),
                  SizedBox(width: scale.sm),
                  Expanded(
                    child: Text(
                      _healthSummary(healthSnapshot),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: scale.fontSm,
                      ),
                    ),
                  ),
                  if (healthSnapshot.needsFix)
                    TextButton(
                      onPressed: () =>
                          context.push('/generator/fix', extra: item),
                      child: Text(
                        'Fix now',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: scale.md),
            ],
            ...item.fields.entries
                .where((e) =>
                    e.key != passwordChangedAtKey && '${e.value}'.isNotEmpty)
                .map((e) {
              final key = e.key;
              final value = '${e.value}';
              final label = titleCaseLabel(key);
              if (_sensitiveKeys.contains(key)) {
                return Padding(
                  padding: EdgeInsets.only(bottom: scale.md),
                  child: MaskedSecretField(
                    label: label,
                    value: value,
                    revealed: _revealed.contains(key),
                    onToggle: () => _toggleReveal(key),
                    onCopy: () => _copySecret(key, value),
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
                        label,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: scale.fontSm,
                          fontWeight: FontWeight.w500,
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
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: scale.fontSm,
              ),
            ),
            Text(
              'Updated ${dateFormat.format(item.updatedAt)}',
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: scale.fontSm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _healthSummary(ItemHealthSnapshot snapshot) {
    final parts = <String>[snapshot.strength.strength.name];
    if (snapshot.isReused) parts.add('reused');
    if (snapshot.isOld) parts.add('old');
    return parts.join(' · ');
  }
}
