/// Shared attachments picker/list for vault forms and detail screens.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';
import 'package:nucleus/features/attachments/domain/entities/pending_attachment.dart';
import 'package:nucleus/features/attachments/domain/entities/vault_attachment.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';
import 'package:nucleus/core/platform/open_local_file.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/ui_list_group.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AttachmentsSection extends ConsumerStatefulWidget {
  const AttachmentsSection({
    super.key,
    required this.vaultItemId,
    required this.syncMode,
    this.readOnly = false,
    this.pendingFiles = const [],
    this.onPendingFilesChanged,
    this.onAttachmentIdsChanged,
  });

  final String? vaultItemId;
  final VaultSyncMode syncMode;
  final bool readOnly;
  final List<PendingAttachment> pendingFiles;
  final void Function(List<PendingAttachment> files)? onPendingFilesChanged;
  final void Function(List<String> ids)? onAttachmentIdsChanged;

  @override
  ConsumerState<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<AttachmentsSection> {
  List<VaultAttachment> _attachments = [];
  bool _loading = false;
  double? _progress;
  String? _busyAttachmentId;

  @override
  void initState() {
    super.initState();
    if (widget.vaultItemId != null) {
      _load();
    }
  }

  @override
  void didUpdateWidget(AttachmentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vaultItemId != null &&
        widget.vaultItemId != oldWidget.vaultItemId) {
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.vaultItemId;
    final dek = ref.read(vaultSessionProvider).dek;
    if (id == null || dek == null) return;
    setState(() => _loading = true);
    try {
      final list = await ref.read(attachmentRepositoryProvider).listForItem(
            vaultItemId: id,
            dek: dek,
          );
      if (!mounted) return;
      setState(() => _attachments = list);
      widget.onAttachmentIdsChanged?.call(list.map((e) => e.id).toList());
    } catch (e) {
      if (!mounted) return;
      final message = await userFacingErrorMessage(
        ref.read(connectivityServiceProvider),
        e,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _guessMime(String? extension, String filename) {
    return lookupMimeType(filename) ??
        (extension != null && extension.isNotEmpty
            ? 'application/$extension'
            : null) ??
        'application/octet-stream';
  }

  /// Prefer filename-based MIME so viewers (PDF, images) get the right intent.
  String _mimeForOpen(VaultAttachment attachment) {
    return lookupMimeType(attachment.originalFilename) ??
        attachment.mimeType;
  }

  Future<void> _pickFiles() async {
    if (widget.syncMode == VaultSyncMode.local) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Turn on Sync to Cloud to attach files (cloud storage required).',
          ),
        ),
      );
      return;
    }

    final files = await FilePicker.pickFiles(allowMultiple: true);
    if (files.isEmpty) return;

    final vaultItemId = widget.vaultItemId;
    final session = ref.read(vaultSessionProvider);
    final dek = session.dek;
    final userId = ref.read(authRepositoryProvider).currentUserId;

    if (vaultItemId == null) {
      final pending = [...widget.pendingFiles];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        pending.add(
          PendingAttachment(
            filename: file.name,
            bytes: bytes,
            mimeType: _guessMime(file.extension, file.name),
          ),
        );
      }
      widget.onPendingFilesChanged?.call(pending);
      if (mounted) setState(() {});
      return;
    }

    if (dek == null || userId == null) return;

    final repo = ref.read(attachmentRepositoryProvider);
    for (final file in files) {
      final fileBytes = await file.readAsBytes();
      setState(() => _progress = 0);
      await repo.uploadFile(
        userId: userId,
        vaultItemId: vaultItemId,
        dek: dek,
        fileBytes: fileBytes,
        filename: file.name,
        mimeType: _guessMime(file.extension, file.name),
        onProgress: (f) => setState(() => _progress = f),
      );
    }
    setState(() => _progress = null);
    await _load();
  }

  void _removePending(int index) {
    final pending = [...widget.pendingFiles]..removeAt(index);
    widget.onPendingFilesChanged?.call(pending);
    setState(() {});
  }

  Future<void> _openAttachment(VaultAttachment attachment) async {
    final dek = ref.read(vaultSessionProvider).dek;
    if (dek == null) return;
    setState(() => _busyAttachmentId = attachment.id);
    try {
      final bytes = await ref.read(attachmentRepositoryProvider).downloadFile(
            attachment: attachment,
            dek: dek,
          );
      final dir = await getTemporaryDirectory();
      final safeName = p.basename(attachment.originalFilename);
      final path = p.join(dir.path, '${attachment.id}_$safeName');
      await File(path).writeAsBytes(bytes);
      if (!mounted) return;
      final error = await openLocalFile(
        path: path,
        mimeType: _mimeForOpen(attachment),
      );
      if (!mounted) return;
      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = await userFacingErrorMessage(
        ref.read(connectivityServiceProvider),
        e,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busyAttachmentId = null);
    }
  }

  Future<void> _downloadAttachment(VaultAttachment attachment) async {
    final dek = ref.read(vaultSessionProvider).dek;
    if (dek == null) return;
    setState(() => _busyAttachmentId = attachment.id);
    try {
      final bytes = await ref.read(attachmentRepositoryProvider).downloadFile(
            attachment: attachment,
            dek: dek,
          );
      final uri = await FilePicker.saveFile(
        fileName: attachment.originalFilename,
        bytes: bytes,
        mimeType: attachment.mimeType,
      );
      if (uri == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File saved')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = await userFacingErrorMessage(
        ref.read(connectivityServiceProvider),
        e,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busyAttachmentId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;
    final canAdd = !widget.readOnly && widget.syncMode == VaultSyncMode.cloud;
    final showPending = !widget.readOnly && widget.vaultItemId == null;
    final pending = showPending ? widget.pendingFiles : const <PendingAttachment>[];
    final hasFiles = pending.isNotEmpty || _attachments.isNotEmpty;

    final rows = <Widget>[
      if (_loading)
        Padding(
          padding: EdgeInsets.symmetric(vertical: scale.md),
          child: Center(
            child: SizedBox(
              width: scale.s(22),
              height: scale.s(22),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
          ),
        )
      else ...[
        for (final entry in pending.asMap().entries)
          _FileRow(
            title: entry.value.filename,
            subtitle:
                '${_formatKb(entry.value.bytes.length)} · pending upload',
            onRemove: widget.readOnly ? null : () => _removePending(entry.key),
          ),
        for (final a in _attachments)
          _FileRow(
            title: a.originalFilename,
            subtitle: _formatKb(a.sizeBytes),
            busy: _busyAttachmentId == a.id,
            onOpen: () => _openAttachment(a),
            onDownload: () => _downloadAttachment(a),
          ),
        if (!hasFiles && !canAdd)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: scale.md,
              vertical: scale.sm + 2,
            ),
            child: Text(
              widget.syncMode == VaultSyncMode.local
                  ? 'Turn on Sync to Cloud to attach files.'
                  : 'No files attached',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: scale.fontSm,
                height: 1.35,
              ),
            ),
          ),
        if (canAdd)
          UiNavRow(
            icon: 'plus',
            title: 'Add files',
            subtitle: hasFiles
                ? null
                : (widget.vaultItemId == null
                    ? 'Add files before saving (required for documents).'
                    : 'PDF, images, and other files'),
            onTap: _pickFiles,
            trailing: const SizedBox.shrink(),
          ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Attachments',
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: scale.fontSm,
          ),
        ),
        SizedBox(height: scale.sm),
        if (_progress != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(scale.radiusSm),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 3,
              color: colors.primary,
              backgroundColor: colors.surfaceMuted,
            ),
          ),
          SizedBox(height: scale.sm),
        ],
        UiGroupedCard(children: rows),
      ],
    );
  }
}

String _formatKb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';

/// One file in the attachments card (pending or uploaded).
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.title,
    required this.subtitle,
    this.busy = false,
    this.onOpen,
    this.onDownload,
    this.onRemove,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback? onDownload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return InkWell(
      onTap: busy ? null : onOpen,
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
                child: AppIcon('note', size: scale.iconSm, color: colors.primary),
              ),
            ),
            SizedBox(width: scale.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: scale.fontMd,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: scale.xs / 2),
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
            if (busy)
              SizedBox(
                width: scale.s(22),
                height: scale.s(22),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              )
            else ...[
              if (onDownload != null)
                IconButton(
                  tooltip: 'Download',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: scale.s(36),
                    minHeight: scale.s(36),
                  ),
                  onPressed: onDownload,
                  icon: Icon(
                    Icons.download_outlined,
                    size: scale.iconSm,
                    color: colors.textSecondary,
                  ),
                ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: scale.s(36),
                    minHeight: scale.s(36),
                  ),
                  onPressed: onRemove,
                  icon: AppIcon(
                    'close',
                    size: scale.iconSm,
                    color: colors.textSecondary,
                  ),
                ),
              if (onOpen != null && onRemove == null)
                AppIcon(
                  'chevron_right',
                  color: colors.textTertiary,
                  size: scale.iconSm,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Uploads pending files after a new vault item is created.
Future<void> uploadPendingAttachments({
  required WidgetRef ref,
  required String userId,
  required String vaultItemId,
  required Uint8List dek,
  required List<PendingAttachment> pending,
}) async {
  if (pending.isEmpty) return;
  final repo = ref.read(attachmentRepositoryProvider);
  for (final file in pending) {
    await repo.uploadFile(
      userId: userId,
      vaultItemId: vaultItemId,
      dek: dek,
      fileBytes: file.bytes,
      filename: file.filename,
      mimeType: file.mimeType,
    );
  }
}
