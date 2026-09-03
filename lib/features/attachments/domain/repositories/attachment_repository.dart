/// Attachment list/upload/delete for encrypted vault files.
import 'dart:typed_data';

import 'package:nucleus/features/attachments/domain/entities/vault_attachment.dart';

typedef AttachmentProgress = void Function(double fraction);

abstract class AttachmentRepository {
  Future<List<VaultAttachment>> listForItem({
    required String vaultItemId,
    required Uint8List dek,
  });

  Future<VaultAttachment> uploadFile({
    required String userId,
    required String vaultItemId,
    required Uint8List dek,
    required Uint8List fileBytes,
    required String filename,
    required String mimeType,
    AttachmentProgress? onProgress,
  });

  Future<Uint8List> downloadFile({
    required VaultAttachment attachment,
    required Uint8List dek,
    AttachmentProgress? onProgress,
  });

  Future<void> deleteAttachment({
    required VaultAttachment attachment,
    required Uint8List dek,
  });
}
