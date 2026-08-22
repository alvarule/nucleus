/// Triage/fix view for password health — filters, grouping, Fix now.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/health/domain/entities/item_health_snapshot.dart';
import 'package:nucleus/features/health/domain/password_health_checker.dart';
import 'package:nucleus/features/health/domain/password_health_display.dart';
import 'package:nucleus/features/health/domain/use_cases/evaluate_password_health.dart';
import 'package:nucleus/features/health/presentation/providers/password_health_provider.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Password Health')),
      body: ListView(
        padding: EdgeInsets.all(scale.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatShortcut(
                  label: 'All',
                  value: '${health.checkedCount}',
                  color: colors.primary,
                  selected: _filter == HealthFilter.all,
                  onTap: () => setState(() => _filter = HealthFilter.all),
                ),
              ),
              SizedBox(width: scale.sm),
              Expanded(
                child: _StatShortcut(
                  label: 'Weak',
                  value: '${health.weakCount}',
                  color: colors.warning,
                  selected: _filter == HealthFilter.weak,
                  onTap: () => setState(() => _filter = HealthFilter.weak),
                ),
              ),
              SizedBox(width: scale.sm),
              Expanded(
                child: _StatShortcut(
                  label: 'Reused',
                  value: '${health.reusedCount}',
                  color: colors.danger,
                  selected: _filter == HealthFilter.reused,
                  onTap: () => setState(() => _filter = HealthFilter.reused),
                ),
              ),
              SizedBox(width: scale.sm),
              Expanded(
                child: _StatShortcut(
                  label: 'Old',
                  value: '${health.oldCount}',
                  color: colors.textSecondary,
                  selected: _filter == HealthFilter.old,
                  onTap: () => setState(() => _filter = HealthFilter.old),
                ),
              ),
            ],
          ),
          SizedBox(height: scale.lg),
          if (rows.isEmpty)
            Text(
              'Add password items to see health insights.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: scale.fontMd,
              ),
            )
          else if (filtered.isEmpty)
            Text(
              'No items match this filter.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: scale.fontMd,
              ),
            )
          else
            ..._buildListBody(
              context,
              filtered: filtered,
              passwordItems: passwordItems,
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

  Widget _cardFor(_HealthRow row, List<VaultItem> passwordItems) {
    return _HealthRowCard(
      title: healthDisplayTitle(row.item, allPasswordItems: passwordItems),
      snapshot: row.snapshot,
      onFixNow: row.snapshot.needsFix ? () => _openFixFlow(row.item) : null,
    );
  }

  List<Widget> _buildListBody(
    BuildContext context, {
    required List<_HealthRow> filtered,
    required List<VaultItem> passwordItems,
  }) {
    final scale = Scale.of(context);
    final colors = context.colors;

    final attention =
        filtered.where((r) => r.snapshot.isWeak || r.snapshot.isReused).toList();
    final rest =
        filtered.where((r) => !r.snapshot.isWeak && !r.snapshot.isReused).toList();
    _orderRowsByPriority(attention);
    _orderRowsByPriority(rest);

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
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: scale.md, bottom: scale.sm),
            child: Text(
              'Reused password',
              style: TextStyle(
                color: colors.danger,
                fontWeight: FontWeight.w700,
                fontSize: scale.fontSm,
              ),
            ),
          ),
        );
        for (final row in group) {
          widgets.add(_cardFor(row, passwordItems));
        }
      }
      for (final row in weakOnly) {
        widgets.add(_cardFor(row, passwordItems));
      }
    } else {
      for (final row in attention) {
        widgets.add(_cardFor(row, passwordItems));
      }
    }

    if (attention.isNotEmpty && rest.isNotEmpty) {
      widgets.add(SizedBox(height: scale.lg));
    }

    for (final row in rest) {
      widgets.add(_cardFor(row, passwordItems));
    }

    return widgets;
  }

  void _openFixFlow(VaultItem item) {
    context.push('/generator/fix', extra: item);
  }
}

class _HealthRow {
  const _HealthRow({required this.item, required this.snapshot});

  final VaultItem item;
  final ItemHealthSnapshot snapshot;
}

class _HealthRowCard extends StatelessWidget {
  const _HealthRowCard({
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
    final color = switch (snapshot.strength.strength) {
      PasswordStrength.excellent || PasswordStrength.strong => colors.success,
      PasswordStrength.fair => colors.warning,
      PasswordStrength.weak => colors.danger,
    };

    final statusParts = <String>[
      snapshot.strength.strength.name,
      'score ${snapshot.strength.score}',
    ];
    if (snapshot.isReused) statusParts.add('reused');
    if (snapshot.isOld) statusParts.add('old');

    return Container(
      margin: EdgeInsets.only(bottom: scale.sm),
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(scale.radiusMd),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          AppIcon('health', color: color),
          SizedBox(width: scale.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: scale.fontLg,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  statusParts.join(' · '),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: scale.fontSm,
                  ),
                ),
              ],
            ),
          ),
          if (onFixNow != null)
            TextButton(
              onPressed: onFixNow,
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
    );
  }
}

class _StatShortcut extends StatelessWidget {
  const _StatShortcut({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
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
          padding: EdgeInsets.all(scale.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(scale.radiusMd),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: scale.fontXl,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
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
