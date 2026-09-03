/// Vault CRUD contract. All reads/writes require the in-memory DEK.
import 'dart:typed_data';

import 'package:nucleus/features/vault/domain/entities/vault_bulk_sync_result.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';

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
    VaultSyncMode? syncMode,
  });

  Future<VaultItem> updateItem({
    required VaultItem item,
    required Uint8List dek,
  });

  Future<void> deleteItem(String id, {VaultSyncMode? syncMode});

  /// Moves a cloud item to local-only storage (optionally deleting cloud copy).
  Future<VaultItem> moveCloudToLocal({
    required VaultItem cloudItem,
    required Uint8List dek,
    required bool deleteFromCloud,
  });

  /// Uploads a local item to cloud or hides cloud copy on this device only.
  Future<VaultItem> moveLocalToCloud({
    required VaultItem localItem,
    required Uint8List dek,
    required bool uploadNow,
  });

  /// Upload every Drift-only item whose id is not already in Supabase.
  Future<VaultBulkSyncResult> promoteAllLocalOnlyToCloud({
    required String userId,
    required Uint8List dek,
  });

  /// Download each cloud item to local storage and delete its cloud row.
  Future<VaultBulkSyncResult> removeAllCloudItemsToLocal({
    required String userId,
    required Uint8List dek,
  });
}
