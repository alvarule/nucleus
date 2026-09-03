/// Local-only vault rows in Drift (no network).
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/features/vault/data/local/local_vault_database.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';

class LocalVaultRepository {
  LocalVaultRepository(this._db, this._crypto);

  final LocalVaultDatabase _db;
  final VaultCryptoService _crypto;
  final _uuid = const Uuid();

  Future<List<VaultItem>> listItems({
    required String userId,
    required Uint8List dek,
  }) async {
    final rows = await (_db.select(_db.localVaultItems)
          ..where((t) => t.userId.equals(userId)))
        .get();
    final items = <VaultItem>[];
    for (final row in rows) {
      try {
        items.add(await _decryptRow(row, dek));
      } catch (_) {
        // Skip undecryptable local rows so cloud merge can still succeed.
      }
    }    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<VaultItem?> getItem({
    required String id,
    required Uint8List dek,
  }) async {
    final row = await (_db.select(_db.localVaultItems)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _decryptRow(row, dek);
  }

  Future<VaultItem> createItem({
    required String userId,
    required VaultItemType type,
    required Map<String, dynamic> fields,
    required Uint8List dek,
    String? folderId,
    String? id,
  }) async {
    final itemId = id ?? _uuid.v4();
    final now = DateTime.now();
    final aad = utf8.encode('$itemId:${type.dbValue}');
    final blob = await _crypto.encryptPayload(
      dek: dek,
      plaintextJson: jsonEncode(fields),
      aad: aad,
    );
    await _db.into(_db.localVaultItems).insert(
          LocalVaultItemsCompanion.insert(
            id: itemId,
            userId: userId,
            itemType: type.dbValue,
            folderId: Value(folderId),
            encryptedPayload: blob.ciphertextBase64,
            nonce: blob.nonceBase64,
            createdAtMs: now.millisecondsSinceEpoch,
            updatedAtMs: now.millisecondsSinceEpoch,
          ),
        );
    return VaultItem(
      id: itemId,
      userId: userId,
      type: type,
      fields: fields,
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
      syncMode: VaultSyncMode.local,
    );
  }

  Future<VaultItem> updateItem({
    required VaultItem item,
    required Uint8List dek,
  }) async {
    final now = DateTime.now();
    final aad = utf8.encode('${item.id}:${item.type.dbValue}');
    final blob = await _crypto.encryptPayload(
      dek: dek,
      plaintextJson: jsonEncode(item.fields),
      aad: aad,
    );
    await (_db.update(_db.localVaultItems)..where((t) => t.id.equals(item.id)))
        .write(
      LocalVaultItemsCompanion(
        folderId: Value(item.folderId),
        encryptedPayload: Value(blob.ciphertextBase64),
        nonce: Value(blob.nonceBase64),
        updatedAtMs: Value(now.millisecondsSinceEpoch),
      ),
    );
    return item.copyWith(
      fields: item.fields,
    );
  }

  Future<void> deleteItem(String id) async {
    await (_db.delete(_db.localVaultItems)..where((t) => t.id.equals(id))).go();
  }

  Future<VaultItem> _decryptRow(LocalVaultItem row, Uint8List dek) async {
    try {
      final type = VaultItemTypeX.fromDb(row.itemType);
      final aad = utf8.encode('${row.id}:${type.dbValue}');
      final json = await _crypto.decryptPayload(
        dek: dek,
        blob: EncryptedBlob(
          ciphertextBase64: row.encryptedPayload,
          nonceBase64: row.nonce,
        ),
        aad: aad,
      );
      final fields = Map<String, dynamic>.from(jsonDecode(json) as Map);
      return VaultItem(
        id: row.id,
        userId: row.userId,
        type: type,
        fields: fields,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAtMs),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAtMs),
        folderId: row.folderId,
        syncMode: VaultSyncMode.local,
      );
    } catch (e) {
      throw VaultException('Failed to decrypt local vault item', cause: e);
    }
  }
}
