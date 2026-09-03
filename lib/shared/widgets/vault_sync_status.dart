/// Compact cloud vs device-only indicator for vault items.
import 'package:flutter/material.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';

class VaultSyncStatusChip extends StatelessWidget {
  const VaultSyncStatusChip({
    super.key,
    required this.syncMode,
    this.compact = false,
  });

  final VaultSyncMode syncMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final isCloud = syncMode == VaultSyncMode.cloud;

    final label = isCloud ? 'Cloud sync' : 'This device only';
    final icon = isCloud ? Icons.cloud_outlined : null;
    // Same selected/unselected language as Settings appearance chips.
    final bg = isCloud ? colors.primarySoft : colors.surface;
    final fg = isCloud ? colors.primary : colors.textSecondary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? scale.sm : scale.md,
        vertical: compact ? scale.xs : scale.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(scale.radiusSm),
        border: Border.all(
          color: isCloud ? colors.primary : colors.border,
          width: isCloud ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: scale.iconSm, color: fg)
          else
            AppIcon('device', size: scale.iconSm, color: fg),
          SizedBox(width: scale.xs),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: scale.fontSm,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Form row: label + subtitle + iOS-style switch for cloud sync toggle.
class VaultSyncModeSwitch extends StatelessWidget {
  const VaultSyncModeSwitch({
    super.key,
    required this.syncToCloud,
    required this.subtitle,
    required this.onChanged,
    this.enabled = true,
  });

  final bool syncToCloud;
  final String subtitle;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sync to cloud',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: scale.fontSm,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: scale.sm),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(scale.radiusMd),
          child: InkWell(
            onTap: enabled && onChanged != null
                ? () => onChanged!(!syncToCloud)
                : null,
            borderRadius: BorderRadius.circular(scale.radiusMd),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: scale.md,
                vertical: scale.sm + 2,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(scale.radiusMd),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: scale.s(40),
                    height: scale.s(40),
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(scale.radiusSm),
                    ),
                    child: Center(
                      child: syncToCloud
                          ? Icon(
                              Icons.cloud_outlined,
                              size: scale.iconSm,
                              color: colors.primary,
                            )
                          : AppIcon(
                              'device',
                              size: scale.iconSm,
                              color: colors.primary,
                            ),
                    ),
                  ),
                  SizedBox(width: scale.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          syncToCloud ? 'Cloud backup' : 'Local only',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: scale.fontMd,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: scale.xs / 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: scale.fontSm,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: syncToCloud,
                    onChanged: enabled ? onChanged : null,
                    activeThumbColor: colors.onPrimary,
                    activeTrackColor: colors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
