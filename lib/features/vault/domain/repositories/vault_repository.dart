/// Vault CRUD contract. All reads/writes require the in-memory DEK.
import 'dart:typed_data';

import 'package:nucleus/features/vault/domain/entities/vault_item.dart';

abstract class VaultRepository {
  Future<List<VaultItem>> listItems({
    required String userId,
    required Uint8List dek,
  });

  Future<VaultItem> getItem({
    required String id,
    required Uint8List dek,
  });

  Future<VaultItem> createItem({
    required String userId,
    required VaultItemType type,
    required Map<String, dynamic> fields,
    required Uint8List dek,
    String? folderId,
  });

  Future<VaultItem> updateItem({
    required VaultItem item,
    required Uint8List dek,
  });

  Future<void> deleteItem(String id);
}
