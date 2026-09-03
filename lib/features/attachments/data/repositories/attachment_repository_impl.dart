/// Client-side chunk encryption and Supabase Storage upload for attachments.
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/offline_messages.dart';
import 'package:nucleus/core/network/connectivity_service.dart';
import 'package:nucleus/features/attachments/domain/entities/vault_attachment.dart';
import 'package:nucleus/features/attachments/domain/repositories/attachment_repository.dart';

class AttachmentRepositoryImpl implements AttachmentRepository {
  AttachmentRepositoryImpl(
    this._client,
    this._crypto,
    this._connectivity,
  );

  final SupabaseClient _client;
  final VaultCryptoService _crypto;
  final ConnectivityService _connectivity;
  final _uuid = const Uuid();

  static const _bucket = 'vault-files';
  static const _chunkPlaintextSize = 4 * 1024 * 1024;
  static const _singleChunkMax = 5 * 1024 * 1024;

  Future<void> _ensureOnline() async {
    if (!await _connectivity.hasConnection()) {
      throw OfflineException(randomOfflineMessage());
    }
  }

  @override
  Future<List<VaultAttachment>> listForItem({
    required String vaultItemId,
    required Uint8List dek,
  }) async {
    await _ensureOnline();
    final rows = await _client
        .from('vault_attachments')
        .select()
        .eq('vault_item_id', vaultItemId)
        .order('created_at');
    final out = <VaultAttachment>[];
    for (final row in rows as List) {
      out.add(await _mapRow(Map<String, dynamic>.from(row as Map), dek));
    }
    return out;
  }

  @override
  Future<VaultAttachment> uploadFile({
    required String userId,
    required String vaultItemId,
    required Uint8List dek,
    required Uint8List fileBytes,
    required String filename,
    required String mimeType,
    AttachmentProgress? onProgress,
  }) async {
    await _ensureOnline();
    final attachmentId = _uuid.v4();
    final storageRoot = '$userId/$attachmentId/';
    final chunks = _splitChunks(fileBytes);
    final totalSteps = chunks.length + 1;
    var step = 0;

    for (var i = 0; i < chunks.length; i++) {
      final aad = utf8.encode('$attachmentId:$i');
      final packed = await _crypto.encryptBytes(
        dek: dek,
        plaintext: chunks[i],
        aad: aad,
      );
      final path = '$storageRoot$i';
      await _client.storage.from(_bucket).uploadBinary(
            path,
            packed,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'application/octet-stream',
            ),
          );
      step++;
      onProgress?.call(step / totalSteps);
    }

    final meta = {
      'original_filename': filename,
      'mime_type': mimeType,
      'size_bytes': fileBytes.length,
      'chunk_count': chunks.length,
      'chunk_size': _chunkPlaintextSize,
    };
    final metaBlob = await _crypto.encryptPayload(
      dek: dek,
      plaintextJson: jsonEncode(meta),
      aad: utf8.encode('attachment_meta:$attachmentId'),
    );

    final row = await _client.from('vault_attachments').insert({
      'id': attachmentId,
      'user_id': userId,
      'vault_item_id': vaultItemId,
      'storage_root': storageRoot,
      'encrypted_metadata': metaBlob.ciphertextBase64,
      'metadata_nonce': metaBlob.nonceBase64,
    }).select().single();

    onProgress?.call(1);
    return _mapRow(Map<String, dynamic>.from(row), dek);
  }

  @override
  Future<Uint8List> downloadFile({
    required VaultAttachment attachment,
    required Uint8List dek,
    AttachmentProgress? onProgress,
  }) async {
    await _ensureOnline();
    final chunks = <Uint8List>[];
    for (var i = 0; i < attachment.chunkCount; i++) {
      final path = '${attachment.storageRoot}$i';
      final data = await _client.storage.from(_bucket).download(path);
      final aad = utf8.encode('${attachment.id}:$i');
      final plain = await _crypto.decryptBytes(
        dek: dek,
        packed: Uint8List.fromList(data),
        aad: aad,
      );
      chunks.add(plain);
      onProgress?.call((i + 1) / attachment.chunkCount);
    }
    final buffer = BytesBuilder();
    for (final c in chunks) {
      buffer.add(c);
    }
    return buffer.toBytes();
  }

  @override
  Future<void> deleteAttachment({
    required VaultAttachment attachment,
    required Uint8List dek,
  }) async {
    await _ensureOnline();
    for (var i = 0; i < attachment.chunkCount; i++) {
      final path = '${attachment.storageRoot}$i';
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {}
    }
    await _client.from('vault_attachments').delete().eq('id', attachment.id);
  }

  List<Uint8List> _splitChunks(Uint8List bytes) {
    if (bytes.length <= _singleChunkMax) {
      return [bytes];
    }
    final out = <Uint8List>[];
    for (var start = 0; start < bytes.length; start += _chunkPlaintextSize) {
      final end = (start + _chunkPlaintextSize > bytes.length)
          ? bytes.length
          : start + _chunkPlaintextSize;
      out.add(Uint8List.sublistView(bytes, start, end));
    }
    return out;
  }

  Future<VaultAttachment> _mapRow(
    Map<String, dynamic> row,
    Uint8List dek,
  ) async {
    final id = row['id'] as String;
    final metaJson = await _crypto.decryptPayload(
      dek: dek,
      blob: EncryptedBlob(
        ciphertextBase64: row['encrypted_metadata'] as String,
        nonceBase64: row['metadata_nonce'] as String,
      ),
      aad: utf8.encode('attachment_meta:$id'),
    );
    final meta = Map<String, dynamic>.from(jsonDecode(metaJson) as Map);
    return VaultAttachment(
      id: id,
      userId: row['user_id'] as String,
      vaultItemId: row['vault_item_id'] as String,
      storageRoot: row['storage_root'] as String,
      originalFilename: meta['original_filename'] as String? ?? 'file',
      mimeType: meta['mime_type'] as String? ?? 'application/octet-stream',
      sizeBytes: meta['size_bytes'] as int? ?? 0,
      chunkCount: meta['chunk_count'] as int? ?? 1,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
