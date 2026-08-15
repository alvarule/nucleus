/// Encrypts/decrypts vault payloads client-side, then talks to `vault_items`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/repositories/vault_repository.dart';

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl(this._client, this._crypto);

  final SupabaseClient _client;
  final VaultCryptoService _crypto;
  final _uuid = const Uuid();

  @override
  Future<List<VaultItem>> listItems({
    required String userId,
    required Uint8List dek,
  }) async {
    final rows = await _client
        .from('vault_items')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    final items = <VaultItem>[];
    for (final row in rows as List) {
      items.add(await _decrypt(Map<String, dynamic>.from(row as Map), dek));
    }
    return items;
  }

  @override
  Future<VaultItem> getItem({
    required String id,
    required Uint8List dek,
  }) async {
    final row =
        await _client.from('vault_items').select().eq('id', id).single();
    return _decrypt(row, dek);
  }

  @override
  Future<VaultItem> createItem({
    required String userId,
    required VaultItemType type,
    required Map<String, dynamic> fields,
    required Uint8List dek,
  }) async {
    final id = _uuid.v4();
    // AAD ties ciphertext to this row so it cannot be copied onto another item.
    final aad = utf8.encode('$id:${type.dbValue}');
    final blob = await _crypto.encryptPayload(
      dek: dek,
      plaintextJson: jsonEncode(fields),
      aad: aad,
    );
    final payload = {
      'id': id,
      'user_id': userId,
      'item_type': type.dbValue,
      'encrypted_payload': blob.ciphertextBase64,
      'nonce': blob.nonceBase64,
    };
    final row =
        await _client.from('vault_items').insert(payload).select().single();
    return _decrypt(row, dek);
  }

  @override
  Future<VaultItem> updateItem({
    required VaultItem item,
    required Uint8List dek,
  }) async {
    final aad = utf8.encode('${item.id}:${item.type.dbValue}');
    final blob = await _crypto.encryptPayload(
      dek: dek,
      plaintextJson: jsonEncode(item.fields),
      aad: aad,
    );
    final payload = {
      'encrypted_payload': blob.ciphertextBase64,
      'nonce': blob.nonceBase64,
    };
    final row = await _client
        .from('vault_items')
        .update(payload)
        .eq('id', item.id)
        .select()
        .single();
    return _decrypt(row, dek);
  }

  @override
  Future<void> deleteItem(String id) async {
    await _client.from('vault_items').delete().eq('id', id);
  }

  /// Decrypts one `vault_items` row. Failures become [VaultException], not raw crypto errors.
  Future<VaultItem> _decrypt(Map<String, dynamic> row, Uint8List dek) async {
    try {
      final id = row['id'] as String;
      final type = VaultItemTypeX.fromDb(row['item_type'] as String);
      final aad = utf8.encode('$id:${type.dbValue}');
      final json = await _crypto.decryptPayload(
        dek: dek,
        blob: EncryptedBlob(
          ciphertextBase64: row['encrypted_payload'] as String,
          nonceBase64: row['nonce'] as String,
        ),
        aad: aad,
      );
      final fields = Map<String, dynamic>.from(jsonDecode(json) as Map);
      return VaultItem(
        id: id,
        userId: row['user_id'] as String,
        type: type,
        fields: fields,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      );
    } catch (e) {
      throw VaultException('Failed to decrypt vault item', cause: e);
    }
  }
}
