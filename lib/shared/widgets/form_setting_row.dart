/// Compact labeled switch row for settings-style forms (e.g. generator).
import 'package:flutter/material.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';

class FormSettingRow extends StatelessWidget {
  const FormSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: scale.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: scale.fontMd,
                fontWeight: FontWeight.w500,
              ),
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
