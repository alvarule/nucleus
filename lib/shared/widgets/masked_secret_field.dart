import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';

class MaskedSecretField extends StatelessWidget {
  const MaskedSecretField({
    super.key,
    required this.label,
    required this.value,
    required this.revealed,
    required this.onToggle,
    this.canCopy = true,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool revealed;
  final VoidCallback onToggle;
  final bool canCopy;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);
    final display = revealed ? value : '•' * (value.length.clamp(6, 16));

    return Container(
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
            ),
          ),
          SizedBox(height: scale.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  display,
                  style: TextStyle(
                    color: revealed ? colors.textPrimary : colors.textTertiary,
                    fontSize: scale.fontLg,
                    letterSpacing: revealed ? 0 : 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: revealed ? 'Hide' : 'Show',
                onPressed: onToggle,
                icon: AppIcon(
                  revealed ? 'eye_off' : 'eye',
                  color: colors.primary,
                ),
              ),
              if (canCopy)
                IconButton(
                  tooltip: 'Copy',
                  onPressed: onCopy ??
                      () async {
                        await Clipboard.setData(ClipboardData(text: value));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        }
                      },
                  icon: AppIcon('copy', color: colors.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
