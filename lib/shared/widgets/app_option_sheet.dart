/// Shared picker bottom sheet: drag handle, title, selectable rows.
import 'package:flutter/material.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';

class AppSheetOption<T> {
  const AppSheetOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String title;
  final String? subtitle;
  /// Optional leading `AppIcon` name (e.g. vault sort).
  final String? icon;
}

/// Returns the tapped option, or null if dismissed.
Future<T?> showAppOptionSheet<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<AppSheetOption<T>> options,
  required T selected,
}) {
  final colors = context.colors;
  final scale = Scale.of(context);

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(scale.radiusLg)),
    ),
    builder: (ctx) {
      final s = Scale.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(s.md, 0, s.md, s.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: s.fontLg,
                    color: colors.textPrimary,
                  ),
                ),
                if (message != null) ...[
                  SizedBox(height: s.xs),
                  Text(
                    message,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: s.fontSm,
                      height: 1.4,
                    ),
                  ),
                ],
                SizedBox(height: s.md),
                for (var i = 0; i < options.length; i++) ...[
                  _OptionRow(
                    option: options[i],
                    selected: options[i].value == selected,
                    onTap: () => Navigator.pop(ctx, options[i].value),
                  ),
                  if (i < options.length - 1) SizedBox(height: s.sm),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppSheetOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Material(
      color: selected ? colors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(scale.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scale.radiusMd),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: scale.md,
            vertical: scale.sm + 4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(scale.radiusMd),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (option.icon != null) ...[
                AppIcon(
                  option.icon!,
                  size: scale.iconSm,
                  color: selected ? colors.primary : colors.textSecondary,
                ),
                SizedBox(width: scale.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        fontSize: scale.fontMd,
                        fontWeight: FontWeight.w600,
                        color: selected ? colors.primary : colors.textPrimary,
                      ),
                    ),
                    if (option.subtitle != null) ...[
                      SizedBox(height: scale.xs / 2),
                      Text(
                        option.subtitle!,
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
              if (selected)
                AppIcon('check', size: scale.iconSm, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
