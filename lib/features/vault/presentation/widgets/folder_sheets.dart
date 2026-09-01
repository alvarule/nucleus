/// Bottom sheets and dialogs for create / rename / delete / pick folders.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/vault/domain/entities/vault_folder.dart';
import 'package:nucleus/features/vault/domain/folder_sections.dart';
import 'package:nucleus/features/vault/domain/vault_sort.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';

Future<void> _showFolderActionError(
  BuildContext context,
  WidgetRef ref,
  Object error,
) async {
  final message = await userFacingErrorMessage(
    ref.read(connectivityServiceProvider),
    error,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<String?> showFolderNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _FolderNameDialog(title: title, initial: initial),
  );
}

/// Owns its [TextEditingController] so dispose never races the dialog close animation.
class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Scale.of(context);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: scale.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(scale.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(scale.lg),
        child: Form(
          key: _formKey,
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
              SizedBox(height: scale.md),
              TextFormField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: scale.fontMd,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Work',
                  hintStyle: TextStyle(color: colors.textTertiary),
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(scale.sm + 2),
                    child: AppIcon(
                      'folder',
                      size: scale.iconSm,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: scale.lg),
              Row(
                children: [
                  // Expanded(
                  //   child: OutlinedButton(
                  //     onPressed: () => Navigator.pop(context),
                  //     style: OutlinedButton.styleFrom(
                  //       foregroundColor: colors.textSecondary,
                  //       side: BorderSide(color: colors.border),
                  //       padding: EdgeInsets.symmetric(vertical: scale.sm),
                  //     ),
                  //     child: const Text('Cancel'),
                  //   ),
                  // ),
                  // SizedBox(width: scale.sm),
                  // Expanded(
                  //   child: ElevatedButton(
                  //     onPressed: _submit,
                  //     child: const Text('Save'),
                  //   ),
                  // ),
Expanded(
  child: SizedBox(
    height: scale.s(48),
    child: OutlinedButton(
      onPressed: () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textSecondary,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scale.radiusMd),
        ),
      ),
      child: const Text('Cancel'),
    ),
  ),
),
SizedBox(width: scale.sm),
Expanded(
  child: SizedBox(
    height: scale.s(48),
    child: ElevatedButton(
      onPressed: _submit,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scale.radiusMd),
        ),
      ),
      child: const Text('Save'),
    ),
  ),
),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showSortSheet({
  required BuildContext context,
  required WidgetRef ref,
  required VaultSort current,
}) async {
  final colors = context.colors;
  final scale = Scale.of(context);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(scale.radiusLg)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: scale.sm),
                child: Text(
                  'Sort items',
                  style: TextStyle(
                    fontSize: scale.fontLg,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: VaultSort.values.map((sort) {
                    final selected = sort == current;
                    return Padding(
                      padding: EdgeInsets.only(bottom: scale.xs),
                      child: Material(
                        color: selected
                            ? colors.primarySoft
                            : colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(scale.radiusSm),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            ref.read(vaultListProvider.notifier).setSort(sort);
                          },
                          borderRadius:
                              BorderRadius.circular(scale.radiusSm),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: scale.md,
                              vertical: scale.sm + 2,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sort.label,
                                    style: TextStyle(
                                      fontSize: scale.fontMd,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: selected
                                          ? colors.primary
                                          : colors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  AppIcon(
                                    'check',
                                    size: scale.iconSm,
                                    color: colors.primary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Long-press on a section header. Uncategorized only offers create.
Future<void> showFolderManageSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String folderId,
  required String title,
}) async {
  final colors = context.colors;
  final scale = Scale.of(context);
  final isUncategorized = folderId == uncategorizedFolderId;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(scale.radiusLg)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isUncategorized ? 'Uncategorized' : title,
                style: TextStyle(
                  fontSize: scale.fontLg,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: scale.xs),
              Text(
                'Folder actions',
                style: TextStyle(
                  fontSize: scale.fontSm,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: scale.md),
              _SheetAction(
                icon: 'plus',
                label: 'New folder',
                iconColor: colors.primary,
                iconBg: colors.primarySoft,
                onTap: () async {
                  Navigator.pop(ctx);
                  final name = await showFolderNameDialog(
                    context,
                    title: 'Create folder',
                  );
                  if (name == null) return;
                  try {
                    await ref.read(vaultListProvider.notifier).createFolder(name);
                  } catch (e) {
                    await _showFolderActionError(context, ref, e);
                  }
                },
              ),
              if (!isUncategorized) ...[
                SizedBox(height: scale.xs),
                _SheetAction(
                  icon: 'edit',
                  label: 'Rename',
                  iconColor: colors.textSecondary,
                  iconBg: colors.surfaceMuted,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final name = await showFolderNameDialog(
                      context,
                      title: 'Rename folder',
                      initial: title,
                    );
                    if (name == null) return;
                    try {
                      await ref
                          .read(vaultListProvider.notifier)
                          .renameFolder(folderId, name);
                    } catch (e) {
                      await _showFolderActionError(context, ref, e);
                    }
                  },
                ),
                SizedBox(height: scale.xs),
                _SheetAction(
                  icon: 'delete',
                  label: 'Delete',
                  iconColor: colors.danger,
                  iconBg: colors.danger.withValues(alpha: 0.12),
                  labelColor: colors.danger,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        backgroundColor: colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(scale.radiusLg),
                        ),
                        title: const Text('Delete folder?'),
                        content: Text(
                          'Items in "$title" will move to Uncategorized. Items are not deleted.',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: colors.danger),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      try {
                        await ref
                            .read(vaultListProvider.notifier)
                            .deleteFolder(folderId);
                      } catch (e) {
                        await _showFolderActionError(context, ref, e);
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Pick a folder for a vault item. Empty string = Uncategorized.
Future<String?> showFolderPickerSheet({
  required BuildContext context,
  required WidgetRef ref,
  required List<VaultFolder> folders,
  String? selectedId,
}) async {
  final colors = context.colors;
  final scale = Scale.of(context);

  return showModalBottomSheet<String?>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(scale.radiusLg)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose folder',
                style: TextStyle(
                  fontSize: scale.fontLg,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: scale.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _SheetOption(
                      icon: 'folder',
                      label: 'Uncategorized',
                      selected: selectedId == null,
                      onTap: () => Navigator.pop(ctx, ''),
                    ),
                    ...folders.map(
                      (f) => Padding(
                        padding: EdgeInsets.only(top: scale.xs),
                        child: _SheetOption(
                          icon: 'folder',
                          label: f.name,
                          selected: selectedId == f.id,
                          onTap: () => Navigator.pop(ctx, f.id),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: scale.sm),
                      child: _SheetAction(
                        icon: 'plus',
                        label: 'New folder',
                        iconColor: colors.primary,
                        iconBg: colors.primarySoft,
                        onTap: () async {
                          final name = await showFolderNameDialog(
                            ctx,
                            title: 'Create folder',
                          );
                          if (name == null) return;
                          try {
                            final folder = await ref
                                .read(vaultListProvider.notifier)
                                .createFolder(name);
                            if (ctx.mounted && folder != null) {
                              Navigator.pop(ctx, folder.id);
                            }
                          } catch (e) {
                            await _showFolderActionError(ctx, ref, e);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
    this.labelColor,
  });

  final String icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Material(
      color: colors.surfaceMuted,
      borderRadius: BorderRadius.circular(scale.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scale.radiusSm),
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(scale.radiusSm),
                ),
                child: Center(
                  child: AppIcon(icon, size: scale.iconSm, color: iconColor),
                ),
              ),
              SizedBox(width: scale.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: scale.fontMd,
                    fontWeight: FontWeight.w600,
                    color: labelColor ?? colors.textPrimary,
                  ),
                ),
              ),
              AppIcon('chevron_right', color: colors.textTertiary, size: scale.iconSm),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return Material(
      color: selected ? colors.primarySoft : colors.surfaceMuted,
      borderRadius: BorderRadius.circular(scale.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(scale.radiusSm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: scale.md,
            vertical: scale.sm + 2,
          ),
          child: Row(
            children: [
              AppIcon(
                icon,
                size: scale.iconSm,
                color: selected ? colors.primary : colors.textSecondary,
              ),
              SizedBox(width: scale.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: scale.fontMd,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? colors.primary : colors.textPrimary,
                  ),
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
