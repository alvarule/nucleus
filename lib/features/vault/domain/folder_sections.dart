/// Groups filtered vault items under folders. Uncategorized is always last.
import 'package:nucleus/features/vault/domain/entities/vault_folder.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/vault_sort.dart';

/// Sentinel id for the Uncategorized section in UI keys and expand state.
const uncategorizedFolderId = '__uncategorized__';

class VaultFolderSection {
  const VaultFolderSection({
    required this.folderId,
    required this.title,
    required this.items,
  });

  /// Folder uuid, or [uncategorizedFolderId].
  final String folderId;
  final String title;
  final List<VaultItem> items;

  bool get isUncategorized => folderId == uncategorizedFolderId;
}

List<VaultFolderSection> buildFolderSections({
  required List<VaultItem> items,
  required List<VaultFolder> folders,
  required VaultSort sort,
  bool includeEmptyFolders = true,
}) {
  final sortedFolders = [...folders]..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  final sections = <VaultFolderSection>[];
  final knownFolderIds = sortedFolders.map((f) => f.id).toSet();

  for (final folder in sortedFolders) {
    final inFolder = items.where((i) => i.folderId == folder.id).toList();
    sortItems(inFolder, sort);
    if (inFolder.isEmpty && !includeEmptyFolders) continue;
    sections.add(
      VaultFolderSection(
        folderId: folder.id,
        title: folder.name,
        items: inFolder,
      ),
    );
  }

  // Uncategorized: no folder, empty folder id, or folder row missing (offline / deleted).
  final uncategorized = items
      .where(
        (i) =>
            i.folderId == null ||
            i.folderId!.isEmpty ||
            !knownFolderIds.contains(i.folderId),
      )
      .toList();
  sortItems(uncategorized, sort);
  if (uncategorized.isNotEmpty || includeEmptyFolders) {
    sections.add(
      VaultFolderSection(
        folderId: uncategorizedFolderId,
        title: 'Uncategorized',
        items: uncategorized,
      ),
    );
  }
  return sections;
}

void sortItems(List<VaultItem> items, VaultSort sort) {
  items.sort((a, b) {
    switch (sort) {
      case VaultSort.nameAsc:
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      case VaultSort.nameDesc:
        return b.label.toLowerCase().compareTo(a.label.toLowerCase());
      case VaultSort.updatedDesc:
        return b.updatedAt.compareTo(a.updatedAt);
      case VaultSort.updatedAsc:
        return a.updatedAt.compareTo(b.updatedAt);
      case VaultSort.createdDesc:
        return b.createdAt.compareTo(a.createdAt);
      case VaultSort.createdAsc:
        return a.createdAt.compareTo(b.createdAt);
    }
  });
}
