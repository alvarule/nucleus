/// Compact section headers and grouped rows for settings-style screens.
import 'package:flutter/material.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';

/// Uppercase-style section label above a card.
class UiSectionLabel extends StatelessWidget {
  const UiSectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    return Padding(
      padding: padding ??
          EdgeInsets.fromLTRB(scale.xs, scale.md, scale.xs, scale.sm),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: scale.fontSm,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Bordered surface with [Divider] between [children].
class UiGroupedCard extends StatelessWidget {
  const UiGroupedCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final visible = children.where((c) => c is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(scale.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(scale.radiusMd),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              visible[i],
              if (i < visible.length - 1) Divider(height: 1, color: colors.border),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tappable row: soft icon tile, title, optional subtitle, chevron.
class UiNavRow extends StatelessWidget {
  const UiNavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.titleColor,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final ic = iconColor ?? colors.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: scale.md,
          vertical: scale.sm + 2,
        ),
        child: Row(
          children: [
            Container(
              width: scale.s(36),
              height: scale.s(36),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(scale.radiusSm),
              ),
              child: Center(
                child: AppIcon(icon, size: scale.iconSm, color: ic),
              ),
            ),
            SizedBox(width: scale.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: scale.fontMd,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: scale.xs / 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: scale.fontSm,
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                AppIcon('chevron_right', color: colors.textTertiary, size: scale.iconSm),
          ],
        ),
      ),
    );
  }
}

/// Title, subtitle, and adaptive switch (settings defaults).
class UiSwitchRow extends StatelessWidget {
  const UiSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: scale.md,
        vertical: scale.sm,
      ),
      child: Row(
        children: [
          Container(
            width: scale.s(36),
            height: scale.s(36),
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(scale.radiusSm),
            ),
            child: Center(
              child: AppIcon(icon, size: scale.iconSm, color: colors.primary),
            ),
          ),
          SizedBox(width: scale.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: scale.fontMd,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: scale.fontSm,
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.onPrimary,
            activeTrackColor: colors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// Read-only label + value inside a grouped card.
class UiInfoRow extends StatelessWidget {
  const UiInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: scale.md,
        vertical: scale.sm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: scale.iconSm, color: colors.textSecondary),
            SizedBox(width: scale.sm),
          ],
          SizedBox(
            width: scale.s(72),
            child: Text(
              label,
              style: TextStyle(
                fontSize: scale.fontSm,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: scale.fontMd,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
