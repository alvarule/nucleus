/// Small health indicator for vault list rows and detail headers.
import 'package:flutter/material.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/health/domain/entities/item_health_snapshot.dart';

class HealthBadge extends StatelessWidget {
  const HealthBadge({super.key, required this.snapshot});

  final ItemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);
    final color = switch (snapshot.primaryFlag) {
      ItemHealthFlag.fine => colors.success,
      ItemHealthFlag.weak => colors.warning,
      ItemHealthFlag.reused => colors.danger,
      ItemHealthFlag.old => colors.textSecondary,
    };

    return Tooltip(
      message: _tooltip(snapshot),
      child: SizedBox(
        width: scale.s(10),
        height: scale.s(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  String _tooltip(ItemHealthSnapshot snapshot) {
    final parts = <String>[];
    if (snapshot.isReused) parts.add('Reused');
    if (snapshot.isWeak) parts.add('Weak');
    if (snapshot.isOld) parts.add('Old');
    if (parts.isEmpty) return 'Healthy';
    return parts.join(' · ');
  }
}
