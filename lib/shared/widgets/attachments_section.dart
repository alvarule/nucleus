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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Attachments',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: scale.fontSm,
              ),
            ),
            const Spacer(),
            if (canAdd)
              IconButton(
                tooltip: 'Add files',
                onPressed: _pickFiles,
                icon: AppIcon('plus', color: colors.primary),
              ),
          ],
        ),
        if (_progress != null)
          Padding(
            padding: EdgeInsets.only(bottom: scale.sm),
            child: LinearProgressIndicator(
              value: _progress,
              color: colors.primary,
              backgroundColor: colors.surfaceMuted,
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (showPending)
            ...widget.pendingFiles.asMap().entries.map(
                  (e) => _PendingTile(
                    attachment: e.value,
                    onRemove:
                        widget.readOnly ? null : () => _removePending(e.key),
                  ),
                ),
          ..._attachments.map(
            (a) => _AttachmentTile(
              attachment: a,
              busy: _busyAttachmentId == a.id,
              onOpen: () => _openAttachment(a),
              onDownload: () => _downloadAttachment(a),
            ),
          ),
          if (_attachments.isEmpty &&
              (!showPending || widget.pendingFiles.isEmpty))
            Text(
              widget.syncMode == VaultSyncMode.local
                  ? 'Enable Sync to Cloud to attach files.'
                  : (widget.vaultItemId == null && showPending)
                      ? 'Add files before saving (required for documents).'
                      : 'No files attached',
              style: TextStyle(color: colors.textTertiary, fontSize: scale.fontMd),
            ),
        ],
      ],
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.attachment,
    this.onRemove,
  });

  final PendingAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIcon('note', color: colors.primary),
      title: Text(attachment.filename),
      subtitle: Text(
        '${(attachment.bytes.length / 1024).toStringAsFixed(1)} KB · pending upload',
        style: TextStyle(color: colors.textSecondary),
      ),
      trailing: onRemove != null
          ? IconButton(
              icon: AppIcon('close', color: colors.textSecondary),
              onPressed: onRemove,
            )
          : null,
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.busy,
    required this.onOpen,
    required this.onDownload,
  });

  final VaultAttachment attachment;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIcon('note', color: colors.primary),
      title: Text(attachment.originalFilename),
      subtitle: Text(
        '${(attachment.sizeBytes / 1024).toStringAsFixed(1)} KB',
        style: TextStyle(color: colors.textSecondary),
      ),
      trailing: busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Open',
                  onPressed: onOpen,
                  icon: AppIcon('eye', color: colors.primary),
                ),
                IconButton(
                  tooltip: 'Download',
                  onPressed: onDownload,
                  icon: Icon(Icons.download_rounded, color: colors.primary),
                ),
              ],
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
