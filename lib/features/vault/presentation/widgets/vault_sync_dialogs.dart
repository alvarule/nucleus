/// Confirm dialogs for vault sync mode changes (radio + Confirm/Cancel).
import 'package:flutter/material.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';

/// Radio-style choice dialog; [onConfirm] returns the selected value or null.
Future<T?> showSyncRadioDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<SyncRadioOption<T>> options,
  T? initialValue,
  String confirmLabel = 'Confirm',
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => _SyncRadioDialog<T>(
      title: title,
      message: message,
      options: options,
      initialValue: initialValue ?? options.first.value,
      confirmLabel: confirmLabel,
    ),
  );
}

class SyncRadioOption<T> {
  const SyncRadioOption({
    required this.value,
    required this.title,
    this.subtitle,
  });

  final T value;
  final String title;
  final String? subtitle;
}

class _SyncRadioDialog<T> extends StatefulWidget {
  const _SyncRadioDialog({
    required this.title,
    this.message,
    required this.options,
    required this.initialValue,
    required this.confirmLabel,
  });

  final String title;
  final String? message;
  final List<SyncRadioOption<T>> options;
  final T initialValue;
  final String confirmLabel;

  @override
  State<_SyncRadioDialog<T>> createState() => _SyncRadioDialogState<T>();
}

class _SyncRadioDialogState<T> extends State<_SyncRadioDialog<T>> {
  late T _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.surface,
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
              widget.title,
              style: TextStyle(
                fontSize: scale.fontXl,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            if (widget.message != null) ...[
              SizedBox(height: scale.sm),
              Text(
                widget.message!,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: scale.fontMd,
                  height: 1.4,
                ),
              ),
            ],
            SizedBox(height: scale.md),
            ...widget.options.map(
              (opt) => RadioListTile<T>(
                value: opt.value,
                groupValue: _selected,
                onChanged: (v) {
                  if (v != null) setState(() => _selected = v);
                },
                activeColor: colors.primary,
                title: Text(
                  opt.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    fontSize: scale.fontMd,
                  ),
                ),
                subtitle: opt.subtitle != null
                    ? Text(
                        opt.subtitle!,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: scale.fontSm,
                        ),
                      )
                    : null,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(height: scale.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(scale.s(48)),
                      side: BorderSide(color: colors.border),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: scale.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      minimumSize: Size.fromHeight(scale.s(48)),
                    ),
                    child: Text(widget.confirmLabel),
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

Future<bool?> confirmGlobalSyncChange(
  BuildContext context, {
  required VaultSyncMode from,
  required VaultSyncMode to,
}) {
  final body = to == VaultSyncMode.local
      ? 'New items will stay on this device only. Existing items keep their current storage until you change them per item or use the optional bulk step next. This preference syncs to your profile and affects new items on every device.'
      : 'New items will sync to the cloud. Existing items keep their current storage unless you choose to upload local-only items in the next step. This preference syncs to your profile and affects new items on every device.';
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scale = Scale.of(ctx);
      final colors = ctx.colors;
      return Dialog(
        backgroundColor: colors.surface,
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
                to == VaultSyncMode.local
                    ? 'Default: local only?'
                    : 'Default: cloud sync?',
                style: TextStyle(
                  fontSize: scale.fontXl,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: scale.sm),
              Text(
                body,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: scale.fontMd,
                  height: 1.4,
                ),
              ),
              SizedBox(height: scale.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(scale.s(48)),
                        side: BorderSide(color: colors.border),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: scale.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        minimumSize: Size.fromHeight(scale.s(48)),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Whether settings should run a bulk sync after changing the profile default.
enum BulkSyncChoice { performBulk, defaultOnly }

/// Step B when default changes from local to cloud.
Future<BulkSyncChoice?> confirmBulkUploadLocalItems(BuildContext context) {
  return showSyncRadioDialog<BulkSyncChoice>(
    context: context,
    title: 'Upload existing local items?',
    message:
        'You can upload all items stored only on this device to the cloud. Items already in the cloud are not duplicated. Requires an internet connection.',
    initialValue: BulkSyncChoice.defaultOnly,
    options: const [
      SyncRadioOption(
        value: BulkSyncChoice.performBulk,
        title: 'Upload all local-only items',
        subtitle: 'Copies each local item to the cloud, then removes the local-only copy.',
      ),
      SyncRadioOption(
        value: BulkSyncChoice.defaultOnly,
        title: 'Default only',
        subtitle: 'Change the default for new items; leave existing items as they are.',
      ),
    ],
  );
}

/// Step B when default changes from cloud to local.
Future<BulkSyncChoice?> confirmBulkDeleteCloudItems(BuildContext context) {
  return showSyncRadioDialog<BulkSyncChoice>(
    context: context,
    title: 'Remove items from the cloud?',
    message:
        'You can delete all vault items from the cloud and keep copies on this device only. This affects every device signed into your account.',
    initialValue: BulkSyncChoice.defaultOnly,
    options: const [
      SyncRadioOption(
        value: BulkSyncChoice.performBulk,
        title: 'Delete all items from the cloud',
        subtitle:
            'Keeps a local copy on this device and removes cloud rows and attachments.',
      ),
      SyncRadioOption(
        value: BulkSyncChoice.defaultOnly,
        title: 'Default only',
        subtitle: 'Change the default for new items; leave cloud items in the cloud.',
      ),
    ],
  );
}
