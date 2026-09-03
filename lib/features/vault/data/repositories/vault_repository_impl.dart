/// Merges cloud Supabase items with Drift local-only rows by id.
import 'dart:typed_data';

import 'package:nucleus/features/vault/data/local/cloud_sync_exclusion_store.dart';
import 'package:nucleus/features/vault/data/repositories/cloud_vault_repository.dart';
import 'package:nucleus/features/vault/data/repositories/local_vault_repository.dart';
import 'package:nucleus/features/vault/domain/entities/vault_bulk_sync_result.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/entities/vault_sync_mode.dart';
import 'package:nucleus/features/vault/domain/repositories/vault_repository.dart';

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl({
    required CloudVaultRepository cloud,
    required LocalVaultRepository local,
    required CloudSyncExclusionStore exclusions,
  })  : _cloud = cloud,
        _local = local,
        _exclusions = exclusions;

  final CloudVaultRepository _cloud;
  final LocalVaultRepository _local;
  final CloudSyncExclusionStore _exclusions;

  @override
  Future<List<VaultItem>> listItems({
    required String userId,
    required Uint8List dek,
  }) async {
    final excluded = await _exclusions.loadExcludedIds(userId);
    List<VaultItem> local = [];
    try {
      local = await _local.listItems(userId: userId, dek: dek);
    } catch (_) {
      // Drift unavailable or bulk failure — still attempt cloud.
    }
    List<VaultItem> cloud = [];
    try {
      cloud = await _cloud.listItems(
        userId: userId,
        dek: dek,
        excludedIds: excluded,
      );
    } catch (_) {
      // Offline: still show local items.
    }
    final byId = <String, VaultItem>{};
    for (final item in cloud) {
      byId[item.id] = item;
    }
    for (final item in local) {
      byId[item.id] = item;
    }
    final merged = byId.values.toList();
    merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return merged;
  }

  @override
  Future<VaultItem> getItem({
    required String id,
    required Uint8List dek,
  }) async {
    final local = await _local.getItem(id: id, dek: dek);
    if (local != null) return local;
    final cloud = await _cloud.getItem(id: id, dek: dek);
    if (cloud != null) return cloud;
    throw StateError('Vault item not found');
  }

  @override
  Future<VaultItem> createItem({
    required String userId,
    required VaultItemType type,
    required Map<String, dynamic> fields,
    required Uint8List dek,
    String? folderId,
    VaultSyncMode? syncMode,
  }) async {
    final mode = syncMode ?? VaultSyncMode.cloud;
    if (mode == VaultSyncMode.local) {
      return _local.createItem(
        userId: userId,
        type: type,
        fields: fields,
        dek: dek,
        folderId: folderId,
      );
    }
    return _cloud.createItem(
      userId: userId,
      type: type,
      fields: fields,
      dek: dek,
      folderId: folderId,
      syncMode: VaultSyncMode.cloud,
    );
  }

  @override
  Future<VaultItem> updateItem({
    required VaultItem item,
    required Uint8List dek,
  }) async {
    if (item.syncMode == VaultSyncMode.local) {
      return _local.updateItem(item: item, dek: dek);
    }
    return _cloud.updateItem(item: item, dek: dek);
  }

  @override
  Future<void> deleteItem(String id, {VaultSyncMode? syncMode}) async {
    if (syncMode == VaultSyncMode.local) {
      await _local.deleteItem(id);
      return;
    }
    if (syncMode == VaultSyncMode.cloud) {
      await _cloud.deleteItem(id);
      return;
    }
    try {
      await _local.deleteItem(id);
    } catch (_) {}
    try {
      await _cloud.deleteItem(id);
    } catch (_) {}
  }

  @override
  Future<VaultItem> moveCloudToLocal({
    required VaultItem cloudItem,
    required Uint8List dek,
    required bool deleteFromCloud,
  }) async {
  final userId = cloudItem.userId;
    if (deleteFromCloud) {
      await _cloud.deleteItem(cloudItem.id);
      await _exclusions.removeExcluded(userId, cloudItem.id);
    } else {
      await _exclusions.addExcluded(userId, cloudItem.id);
    }
    final local = await _local.createItem(
      userId: userId,
      type: cloudItem.type,
      fields: cloudItem.fields,
      dek: dek,
      folderId: cloudItem.folderId,
      id: deleteFromCloud ? cloudItem.id : null,
    );
    return local;
  }

  @override
  Future<VaultItem> moveLocalToCloud({
    required VaultItem localItem,
    required Uint8List dek,
    required bool uploadNow,
  }) async {
    if (!uploadNow) {
      return localItem;
    }
    final existingCloud =
        await _cloud.getItem(id: localItem.id, dek: dek);
    if (existingCloud != null) {
      await _local.deleteItem(localItem.id);
      return existingCloud;
    }
    final cloud = await _cloud.createItem(
      userId: localItem.userId,
      type: localItem.type,
      fields: localItem.fields,
      dek: dek,
      folderId: localItem.folderId,
      syncMode: VaultSyncMode.cloud,
      id: localItem.id,
    );
    await _local.deleteItem(localItem.id);
    return cloud;
  }

  @override
  Future<VaultBulkSyncResult> promoteAllLocalOnlyToCloud({
    required String userId,
    required Uint8List dek,
  }) async {
    var succeeded = 0;
    var failed = 0;
    var skipped = 0;
    List<VaultItem> localItems;
    try {
      localItems = await _local.listItems(userId: userId, dek: dek);
    } catch (_) {
      return const VaultBulkSyncResult(succeeded: 0, failed: 0, skipped: 0);
    }
    for (final item in localItems) {
      try {
        final inCloud = await _cloud.getItem(id: item.id, dek: dek);
        if (inCloud != null) {
          skipped++;
          continue;
        }
        await moveLocalToCloud(localItem: item, dek: dek, uploadNow: true);
        succeeded++;
      } catch (_) {
        failed++;
      }
    }
    return VaultBulkSyncResult(
      succeeded: succeeded,
      failed: failed,
      skipped: skipped,
    );
  }

  @override
  Future<VaultBulkSyncResult> removeAllCloudItemsToLocal({
    required String userId,
    required Uint8List dek,
  }) async {
    var succeeded = 0;
    var failed = 0;
    List<VaultItem> cloudItems;
    try {
      cloudItems = await _cloud.listItems(userId: userId, dek: dek);
    } catch (_) {
      return const VaultBulkSyncResult(succeeded: 0, failed: 1, skipped: 0);
    }
    for (final item in cloudItems) {
      try {
        await moveCloudToLocal(
          cloudItem: item,
          dek: dek,
          deleteFromCloud: true,
        );
        succeeded++;
      } catch (_) {
        failed++;
      }
    }
    return VaultBulkSyncResult(
      succeeded: succeeded,
      failed: failed,
      skipped: 0,
    );
  }
}
