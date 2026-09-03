/// Decrypts one item by id and shows fields; secrets stay masked until gated.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/health/domain/entities/item_health_snapshot.dart';
import 'package:nucleus/features/health/presentation/providers/password_health_provider.dart';
import 'package:nucleus/features/health/presentation/widgets/health_badge.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/password_field_helpers.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:nucleus/shared/widgets/app_dialog.dart';
import 'package:nucleus/shared/widgets/app_buttons.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/masked_secret_field.dart';
import 'package:nucleus/shared/widgets/sensitive_access.dart';
import 'package:nucleus/shared/widgets/vault_loader.dart';
import 'package:nucleus/shared/widgets/vault_sync_status.dart';
import 'package:nucleus/shared/widgets/attachments_section.dart';
import 'package:nucleus/shared/widgets/vault_text_field.dart' show titleCaseLabel;

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
      final message = await userFacingErrorMessage(
        ref.read(connectivityServiceProvider),
        e,
      );
      if (!mounted) return;
      setState(() {
        _error = message;
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
          title: Text(item.label),
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
                final confirm = await showAppConfirmDialog(
                  context: context,
                  title: 'Delete item?',
                  message: 'Delete "${item.label}"? This cannot be undone.',
                  confirmLabel: 'Delete',
                  tone: AppConfirmTone.destructive,
                );
                if (!confirm || !context.mounted) return;
                await ref.read(vaultListProvider.notifier).delete(item.id);
                if (context.mounted) context.go('/home');
              },
              icon: AppIcon('delete', color: colors.danger),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(scale.md, scale.sm, scale.md, scale.lg),
          children: [
            Row(
              children: [
                Container(
                  width: scale.s(40),
                  height: scale.s(40),
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(scale.radiusSm),
                  ),
                  child: Center(
                    child: AppIcon(item.type.icon, color: colors.primary),
                  ),
                ),
                SizedBox(width: scale.md),
                Expanded(
                  child: Text(
                    item.type.label,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: scale.fontSm,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                VaultSyncStatusChip(syncMode: item.syncMode, compact: true),
              ],
            ),
            if (healthSnapshot != null) ...[
              SizedBox(height: scale.md),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: scale.md,
                  vertical: scale.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(scale.radiusSm),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
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
                      AppTextButton(
                        label: 'Fix now',
                        onPressed: () =>
                            context.push('/generator/fix', extra: item),
                      ),
                  ],
                ),
              ),
            ],
            SizedBox(height: scale.md),
            _DetailFieldsCard(
              item: item,
              sensitiveKeys: _sensitiveKeys,
              revealed: _revealed,
              onToggleReveal: _toggleReveal,
              onCopySecret: _copySecret,
            ),
            SizedBox(height: scale.md),
            AttachmentsSection(
              vaultItemId: item.id,
              syncMode: item.syncMode,
              readOnly: true,
            ),
            SizedBox(height: scale.sm),
            Text(
              'Created ${dateFormat.format(item.createdAt)} · Updated ${dateFormat.format(item.updatedAt)}',
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

/// Groups non-sensitive fields in one bordered card; sensitive fields stay separate.
class _DetailFieldsCard extends StatelessWidget {
  const _DetailFieldsCard({
    required this.item,
    required this.sensitiveKeys,
    required this.revealed,
    required this.onToggleReveal,
    required this.onCopySecret,
  });

  final VaultItem item;
  final Set<String> sensitiveKeys;
  final Set<String> revealed;
  final Future<void> Function(String key) onToggleReveal;
  final Future<void> Function(String key, String value) onCopySecret;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    final entries = item.fields.entries
        .where((e) => e.key != passwordChangedAtKey && '${e.value}'.isNotEmpty)
        .toList();

    final sensitive = <Widget>[];
    final plain = <MapEntry<String, String>>[];

    for (final e in entries) {
      final value = '${e.value}';
      if (sensitiveKeys.contains(e.key)) {
        sensitive.add(
          Padding(
            padding: EdgeInsets.only(bottom: scale.sm),
            child: MaskedSecretField(
              label: titleCaseLabel(e.key),
              value: value,
              revealed: revealed.contains(e.key),
              onToggle: () => onToggleReveal(e.key),
              onCopy: () => onCopySecret(e.key, value),
            ),
          ),
        );
      } else {
        plain.add(MapEntry(e.key, value));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plain.isNotEmpty)
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(scale.radiusMd),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(scale.radiusMd),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < plain.length; i++) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: scale.md,
                        vertical: scale.sm + 2,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: scale.s(108),
                            child: Text(
                              titleCaseLabel(plain[i].key),
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: scale.fontSm,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              plain[i].value,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: scale.fontMd,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < plain.length - 1)
                      Divider(height: 1, color: colors.border),
                  ],
                ],
              ),
            ),
          ),
        if (sensitive.isNotEmpty) ...[
          if (plain.isNotEmpty) SizedBox(height: scale.sm),
          ...sensitive,
        ],
      ],
    );
  }
}
