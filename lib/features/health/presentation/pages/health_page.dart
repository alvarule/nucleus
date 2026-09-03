/// Triage/fix view for password health — filters, list, Fix now.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/health/domain/entities/item_health_snapshot.dart';
import 'package:nucleus/features/health/domain/password_health_display.dart';
import 'package:nucleus/features/health/presentation/providers/password_health_provider.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:nucleus/shared/widgets/app_buttons.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/vault_loader.dart';

enum HealthFilter { all, weak, reused, old }

class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
  HealthFilter _filter = HealthFilter.all;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final vault = ref.watch(vaultListProvider);
    final health = ref.watch(passwordHealthProvider);

    if (vault.loading) {
      return const VaultLoadingScaffold(message: 'Checking health…');
    }

    final passwordItems =
        vault.items.where((i) => i.type == VaultItemType.password).toList();

    final rows = <_HealthRow>[];
    for (final item in passwordItems) {
      final snapshot = health.forItem(item.id);
      if (snapshot == null) continue;
      rows.add(_HealthRow(item: item, snapshot: snapshot));
    }

    final filtered = rows.where((r) => _matchesFilter(r.snapshot)).toList();
    _orderRowsByPriority(filtered);

    return Scaffold(
      appBar: AppBar(title: const Text('Password Health')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.sm),
            child: Row(
              children: [
                Expanded(
                  child: _StatShortcut(
                    label: 'All',
                    value: '${health.checkedCount}',
                    accent: colors.primary,
                    selected: _filter == HealthFilter.all,
                    onTap: () => setState(() => _filter = HealthFilter.all),
                  ),
                ),
                SizedBox(width: scale.sm),
                Expanded(
                  child: _StatShortcut(
                    label: 'Weak',
                    value: '${health.weakCount}',
                    accent: colors.warning,
                    selected: _filter == HealthFilter.weak,
                    onTap: () => setState(() => _filter = HealthFilter.weak),
                  ),
                ),
                SizedBox(width: scale.sm),
                Expanded(
                  child: _StatShortcut(
                    label: 'Reused',
                    value: '${health.reusedCount}',
                    accent: colors.danger,
                    selected: _filter == HealthFilter.reused,
                    onTap: () => setState(() => _filter = HealthFilter.reused),
                  ),
                ),
                SizedBox(width: scale.sm),
                Expanded(
                  child: _StatShortcut(
                    label: 'Old',
                    value: '${health.oldCount}',
                    accent: colors.textSecondary,
                    selected: _filter == HealthFilter.old,
                    onTap: () => setState(() => _filter = HealthFilter.old),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'Add password items to see health insights.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: scale.fontMd,
                      ),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No items match this filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: scale.fontMd,
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.only(bottom: scale.lg),
                        children: _buildListBody(
                          colors: colors,
                          scale: scale,
                          filtered: filtered,
                          passwordItems: passwordItems,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(ItemHealthSnapshot snapshot) {
    return switch (_filter) {
      HealthFilter.all => true,
      HealthFilter.weak => snapshot.isWeak,
      HealthFilter.reused => snapshot.isReused,
      HealthFilter.old => snapshot.isOld,
    };
  }

  void _orderRowsByPriority(List<_HealthRow> rows) {
    rows.sort((a, b) {
      final band = _attentionPriority(a.snapshot)
          .compareTo(_attentionPriority(b.snapshot));
      if (band != 0) return band;
      return a.snapshot.strength.score.compareTo(b.snapshot.strength.score);
    });
  }

  int _attentionPriority(ItemHealthSnapshot snapshot) {
    if (snapshot.isReused || snapshot.isWeak) return 0;
    if (snapshot.isOld) return 1;
    return 2;
  }

  void _openFixFlow(VaultItem item) {
    context.push('/generator/fix', extra: item);
  }

  List<Widget> _buildListBody({
    required AppColors colors,
    required Scale scale,
    required List<_HealthRow> filtered,
    required List<VaultItem> passwordItems,
  }) {
    final attention =
        filtered.where((r) => r.snapshot.isWeak || r.snapshot.isReused).toList();
    final rest =
        filtered.where((r) => !r.snapshot.isWeak && !r.snapshot.isReused).toList();
    _orderRowsByPriority(attention);
    _orderRowsByPriority(rest);

    Widget tile(_HealthRow row) {
      return Column(
        children: [
          _HealthEntryTile(
            title: healthDisplayTitle(row.item, allPasswordItems: passwordItems),
            snapshot: row.snapshot,
            onFixNow:
                row.snapshot.needsFix ? () => _openFixFlow(row.item) : null,
          ),
          Divider(height: 1, color: colors.border),
        ],
      );
    }

    Widget header(String text, {Color? color}) {
      return Padding(
        padding: EdgeInsets.fromLTRB(scale.md, scale.md, scale.md, scale.xs),
        child: Text(
          text,
          style: TextStyle(
            color: color ?? colors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: scale.fontSm,
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    final widgets = <Widget>[];
    final showReusedGroups = _filter == HealthFilter.reused ||
        (_filter == HealthFilter.all && attention.any((r) => r.snapshot.isReused));

    if (showReusedGroups) {
      final reusedRows = attention.where((r) => r.snapshot.isReused).toList();
      final weakOnly = attention.where((r) => !r.snapshot.isReused).toList();
      final groups = <String, List<_HealthRow>>{};
      for (final row in reusedRows) {
        final pwd = '${row.item.fields['password'] ?? ''}';
        groups.putIfAbsent(pwd, () => []).add(row);
      }
      for (final group in groups.values) {
        widgets.add(header('Reused password', color: colors.danger));
        for (final row in group) {
          widgets.add(tile(row));
        }
      }
      if (weakOnly.isNotEmpty) {
        widgets.add(header('Weak'));
        for (final row in weakOnly) {
          widgets.add(tile(row));
        }
      }
    } else if (attention.isNotEmpty) {
      widgets.add(header('Needs attention', color: colors.danger));
      for (final row in attention) {
        widgets.add(tile(row));
      }
    }

    if (rest.isNotEmpty) {
      final restTitle =
          _filter == HealthFilter.old ? 'Older passwords' : 'Secure';
      widgets.add(
        header(
          restTitle,
          color: _filter == HealthFilter.old ? colors.warning : colors.success,
        ),
      );
      for (final row in rest) {
        widgets.add(tile(row));
      }
    }

    return widgets;
  }
}

class _HealthRow {
  const _HealthRow({required this.item, required this.snapshot});

  final VaultItem item;
  final ItemHealthSnapshot snapshot;
}

/// Same structure as vault home / MFA tiles: rose well, title, subtitle, action.
class _HealthEntryTile extends StatelessWidget {
  const _HealthEntryTile({
    required this.title,
    required this.snapshot,
    this.onFixNow,
  });

  final String title;
  final ItemHealthSnapshot snapshot;
  final VoidCallback? onFixNow;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    final statusParts = <String>[
      snapshot.strength.strength.name,
      'score ${snapshot.strength.score}',
    ];
    if (snapshot.isReused) statusParts.add('reused');
    if (snapshot.isOld) statusParts.add('old');

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: scale.md,
        vertical: scale.xs,
      ),
      leading: Container(
        width: scale.s(44),
        height: scale.s(44),
        decoration: BoxDecoration(
          color: colors.primarySoft,
          borderRadius: BorderRadius.circular(scale.radiusSm),
        ),
        child: Center(
          child: AppIcon('health', color: colors.primary),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: scale.fontLg,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        statusParts.join(' · '),
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: scale.fontSm,
        ),
      ),
      trailing: onFixNow == null
          ? null
          : AppTextButton(label: 'Fix', onPressed: onFixNow),
    );
  }
}

/// Filter chip using the same selected rose language as Settings appearance.
class _StatShortcut extends StatelessWidget {
  const _StatShortcut({
    required this.label,
    required this.value,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);
    return Material(
      color: selected ? colors.primarySoft : colors.surface,
      borderRadius: BorderRadius.circular(scale.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scale.radiusMd),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: scale.xs,
            vertical: scale.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(scale.radiusMd),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: scale.fontLg,
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.primary : accent,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? colors.primary : colors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
