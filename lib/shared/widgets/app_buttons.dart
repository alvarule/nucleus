/// Shared CTA styles for primary, secondary, and low-emphasis actions.
import 'package:flutter/material.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';

/// Full-width primary action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.primary.withValues(alpha: 0.35),
        minimumSize: Size.fromHeight(scale.s(48)),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scale.radiusMd),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: scale.fontMd,
        ),
      ),
      child: loading
          ? SizedBox(
              height: scale.s(20),
              width: scale.s(20),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onPrimary,
              ),
            )
          : (icon == null
              ? Text(label)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(icon!, size: scale.iconSm, color: colors.onPrimary),
                    SizedBox(width: scale.sm),
                    Text(label),
                  ],
                )),
    );
  }
}

/// Outlined companion to [PrimaryButton] (copy, secondary paths).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        minimumSize: Size.fromHeight(scale.s(48)),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scale.radiusMd),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: scale.fontMd,
        ),
      ),
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(icon!, size: scale.iconSm, color: colors.primary),
                SizedBox(width: scale.sm),
                Text(label),
              ],
            ),
    );
  }
}

/// Inline text action (save as vault item, fix now, cancel selection).
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final color = destructive ? colors.danger : colors.primary;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: scale.sm,
          vertical: scale.xs,
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: scale.fontMd,
        ),
      ),
      child: Text(label),
    );
  }
}
