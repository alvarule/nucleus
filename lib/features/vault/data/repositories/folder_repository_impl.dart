/// Supabase `vault_folders` adapter.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/offline_messages.dart';
import 'package:nucleus/core/network/connectivity_service.dart';
import 'package:nucleus/features/vault/domain/entities/vault_folder.dart';
import 'package:nucleus/features/vault/domain/repositories/folder_repository.dart';

class FolderRepositoryImpl implements FolderRepository {
  FolderRepositoryImpl(this._client, this._connectivity);

  final SupabaseClient _client;
  final ConnectivityService _connectivity;

  Future<void> _ensureOnline() async {
    if (!await _connectivity.hasConnection()) {
      throw OfflineException(randomOfflineMessage());
    }
  }
  @override
  Future<List<VaultFolder>> listFolders(String userId) async {
    await _ensureOnline();
    final rows = await _client
        .from('vault_folders')
        .select()
        .eq('user_id', userId)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return (rows as List)
        .map((row) => _map(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<VaultFolder> createFolder({
    required String userId,
    required String name,
  }) async {
    await _ensureOnline();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const VaultException('Folder name is required');
    }
    final existing = await listFolders(userId);
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final row = await _client
        .from('vault_folders')
        .insert({
          'user_id': userId,
          'name': trimmed,
          'sort_order': nextOrder,
        })
        .select()
        .single();
    return _map(row);
  }

  @override
  Future<VaultFolder> renameFolder({
    required String id,
    required String name,
  }) async {
    await _ensureOnline();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const VaultException('Folder name is required');
    }
    final row = await _client
        .from('vault_folders')
        .update({'name': trimmed})
        .eq('id', id)
        .select()
        .single();
    return _map(row);
  }

  @override
  Future<void> deleteFolder(String id) async {
    await _ensureOnline();
    await _client.from('vault_folders').delete().eq('id', id);
  }

  VaultFolder _map(Map<String, dynamic> row) {
    return VaultFolder(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
