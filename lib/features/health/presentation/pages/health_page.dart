import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultify/core/responsive/scale.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/features/generator/domain/password_generator.dart';
import 'package:vaultify/features/vault/domain/entities/vault_item.dart';
import 'package:vaultify/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';
import 'package:vaultify/shared/widgets/vault_loader.dart';

class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final vault = ref.watch(vaultListProvider);
    final checker = PasswordHealthChecker();

    if (vault.loading) return const VaultLoadingScaffold(message: 'Checking health…');

    final passwordItems =
        vault.items.where((i) => i.type == VaultItemType.password).toList();
    final passwords = passwordItems
        .map((i) => '${i.fields['password'] ?? ''}')
        .where((p) => p.isNotEmpty)
        .toList();
    final passwordSet = passwords.toSet();

    var weak = 0;
    var reused = 0;
    final rows = <({VaultItem item, PasswordHealthResult result})>[];
    for (final item in passwordItems) {
      final pwd = '${item.fields['password'] ?? ''}';
      if (pwd.isEmpty) continue;
      final result = checker.evaluate(pwd, otherPasswords: passwordSet);
      if (result.strength == PasswordStrength.weak ||
          result.strength == PasswordStrength.fair) {
        weak++;
      }
      if (result.reused) reused++;
      rows.add((item: item, result: result));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Password health')),
      body: ListView(
        padding: EdgeInsets.all(scale.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Checked',
                  value: '${rows.length}',
                  color: colors.primary,
                ),
              ),
              SizedBox(width: scale.sm),
              Expanded(
                child: _StatCard(
                  label: 'Weak',
                  value: '$weak',
                  color: colors.warning,
                ),
              ),
              SizedBox(width: scale.sm),
              Expanded(
                child: _StatCard(
                  label: 'Reused',
                  value: '$reused',
                  color: colors.danger,
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
          else
            ...rows.map((row) {
              final color = switch (row.result.strength) {
                PasswordStrength.excellent || PasswordStrength.strong =>
                  colors.success,
                PasswordStrength.fair => colors.warning,
                PasswordStrength.weak => colors.danger,
              };
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
                            row.item.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: scale.fontLg,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '${row.result.strength.name} · score ${row.result.score}'
                            '${row.result.issues.isEmpty ? '' : ' · ${row.result.issues.first}'}',
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
              );
            }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);
    return Container(
      padding: EdgeInsets.all(scale.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(scale.radiusMd),
        border: Border.all(color: colors.border),
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
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: scale.fontSm)),
        ],
      ),
    );
  }
}
