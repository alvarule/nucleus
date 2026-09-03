/// Consistent confirm dialogs (delete, logout, etc.) across the app.
import 'package:flutter/material.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';

/// Visual weight for the primary action in [showAppConfirmDialog].
enum AppConfirmTone {
  normal,
  destructive,
}

/// Two-button confirm sheet-style dialog. Returns `true` when confirmed.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
  AppConfirmTone tone = AppConfirmTone.normal,
}) async {
  // [tone] kept for callers; confirm always uses the same rose as folder Save.
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AppConfirmDialog(
      title: title,
      message: message,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    ),
  );
  return result == true;
}

class _AppConfirmDialog extends StatelessWidget {
  const _AppConfirmDialog({
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: scale.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(scale.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(scale.lg, scale.lg, scale.lg, scale.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: scale.fontLg,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.25,
              ),
            ),
            SizedBox(height: scale.sm),
            Text(
              message,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: scale.fontMd,
                height: 1.45,
              ),
            ),
            SizedBox(height: scale.lg),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: scale.s(48),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(scale.radiusMd),
                        ),
                        textStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: scale.fontMd,
                        ),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                ),
                SizedBox(width: scale.sm),
                Expanded(
                  child: SizedBox(
                    height: scale.s(48),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        // Same rose as Create folder → Save (theme primary).
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(scale.radiusMd),
                        ),
                        textStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: scale.fontMd,
                        ),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
