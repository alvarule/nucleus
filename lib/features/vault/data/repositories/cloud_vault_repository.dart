/// Cloud `vault_items` CRUD via Supabase (online required).
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/offline_messages.dart';
import 'package:nucleus/core/network/connectivity_service.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';

class CloudVaultRepository {
  CloudVaultRepository(this._client, this._crypto, this._connectivity);

  final SupabaseClient _client;
  final VaultCryptoService _crypto;
  final ConnectivityService _connectivity;
  final _uuid = const Uuid();

  Future<void> _ensureOnline() async {
    if (!await _connectivity.hasConnection()) {
      throw OfflineException(randomOfflineMessage());
    }
  }

  Future<List<VaultItem>> listItems({
    required String userId,
    required Uint8List dek,
    Set<String> excludedIds = const {},
  }) async {
    await _ensureOnline();
    final rows = await _client
        .from('vault_items')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    final items = <VaultItem>[];
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as String;
      if (excludedIds.contains(id)) continue;
      try {
        items.add(await _decrypt(map, dek));
      } catch (_) {
        // Skip rows that cannot be decrypted (legacy AAD, wrong key, corrupt row).
      }
    }
    return items;  }

  Future<VaultItem?> getItem({
    required String id,
    required Uint8List dek,
  }) async {
    await _ensureOnline();
    final row = await _client
        .from('vault_items')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _decrypt(Map<String, dynamic>.from(row), dek);
  }

  Future<VaultItem> createItem({
    required String userId,
    required VaultItemType type,
    required Map<String, dynamic> fields,
    required Uint8List dek,
    String? folderId,
    VaultSyncMode syncMode = VaultSyncMode.cloud,
    String? id,
  }) async {
    await _ensureOnline();
    final itemId = id ?? _uuid.v4();
    final aad = utf8.encode('$itemId:${type.dbValue}');
    final blob = await _crypto.encryptPayload(
      dek: dek,
      plaintextJson: jsonEncode(fields),
      aad: aad,
    );
    final payload = {
      'id': itemId,
      'user_id': userId,
      'item_type': type.dbValue,
      'encrypted_payload': blob.ciphertextBase64,
      'nonce': blob.nonceBase64,
      'folder_id': folderId,
      'sync_mode': vaultSyncModeToDb(syncMode),
    };
    final row =
        await _client.from('vault_items').insert(payload).select().single();
    return _decrypt(row, dek);
  }

  Future<VaultItem> updateItem({
    required VaultItem item,
    required Uint8List dek,
  }) async {
    await _ensureOnline();
    final aad = utf8.encode('${item.id}:${item.type.dbValue}');
    final blob = await _crypto.encryptPayload(
      dek: dek,
      plaintextJson: jsonEncode(item.fields),
      aad: aad,
    );
    final payload = {
      'encrypted_payload': blob.ciphertextBase64,
      'nonce': blob.nonceBase64,
      'folder_id': item.folderId,
      'sync_mode': vaultSyncModeToDb(item.syncMode),
    };
    final row = await _client
        .from('vault_items')
        .update(payload)
        .eq('id', item.id)
        .select()
        .single();
    return _decrypt(row, dek);
  }

  Future<void> deleteItem(String id) async {
    await _ensureOnline();
    await _client.from('vault_items').delete().eq('id', id);
  }

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
      final syncRaw = row['sync_mode'] as String? ?? 'cloud';
      return VaultItem(
        id: id,
        userId: row['user_id'] as String,
        type: type,
        fields: fields,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        folderId: row['folder_id'] as String?,
        syncMode: vaultSyncModeFromDb(syncRaw),
      );
    } catch (e) {
      throw VaultException('Failed to decrypt vault item', cause: e);
    }
  }
}
