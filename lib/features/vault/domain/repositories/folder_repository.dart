/// Folder CRUD. Items stay on `vault_items.folder_id` (null = Uncategorized).
import 'package:nucleus/features/vault/domain/entities/vault_folder.dart';

abstract class FolderRepository {
  Future<List<VaultFolder>> listFolders(String userId);

  Future<VaultFolder> createFolder({
    required String userId,
    required String name,
  });

  Future<VaultFolder> renameFolder({
    required String id,
    required String name,
  });

  /// Deletes the folder. Items are unassigned (Uncategorized) via ON DELETE SET NULL.
  Future<void> deleteFolder(String id);
}
