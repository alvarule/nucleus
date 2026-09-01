/// Decrypted vault list: search, type filter, sort, folders, refresh, delete.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/vault/domain/entities/vault_folder.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/folder_sections.dart';
import 'package:nucleus/features/vault/domain/vault_sort.dart';

class VaultListState {
  const VaultListState({
    this.items = const [],
    this.folders = const [],
    this.loading = false,
    this.hasLoaded = false,
    this.query = '',
    this.filter,
    this.sort = VaultSort.updatedDesc,
    this.error,
  });

  final List<VaultItem> items;
  final List<VaultFolder> folders;
  final bool loading;
  /// False until the first fetch finishes so Home can show a full-page skeleton.
  final bool hasLoaded;
  final String query;
  final VaultItemType? filter;
  final VaultSort sort;
  final String? error;

  /// Client-side filter; search matches label and any field string (all folders).
  List<VaultItem> get visible {
    return items.where((item) {
      if (filter != null && item.type != filter) return false;
      if (query.trim().isEmpty) return true;
      final q = query.toLowerCase();
      return item.label.toLowerCase().contains(q) ||
          item.fields.values.any((v) => '$v'.toLowerCase().contains(q));
    }).toList();
  }

  List<VaultFolderSection> get sections => buildFolderSections(
        items: visible,
        folders: folders,
        sort: sort,
        includeEmptyFolders: query.trim().isEmpty,
      );

  VaultListState copyWith({
    List<VaultItem>? items,
    List<VaultFolder>? folders,
    bool? loading,
    bool? hasLoaded,
    String? query,
    VaultItemType? filter,
    VaultSort? sort,
    String? error,
    bool clearFilter = false,
    bool clearError = false,
  }) {
    return VaultListState(
      items: items ?? this.items,
      folders: folders ?? this.folders,
      loading: loading ?? this.loading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      query: query ?? this.query,
      filter: clearFilter ? null : (filter ?? this.filter),
      sort: sort ?? this.sort,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VaultListNotifier extends StateNotifier<VaultListState> {
  VaultListNotifier(this._ref) : super(const VaultListState()) {
    _loadSort();
  }

  final Ref _ref;
  static const _sortKey = 'vault_home_sort';

  Future<void> _loadSort() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(sort: VaultSortX.fromName(prefs.getString(_sortKey)));
  }

  /// No-ops when the vault is locked so we never decrypt without a DEK.
  Future<void> refresh() async {
    final session = _ref.read(vaultSessionProvider);
    final userId = _ref.read(authRepositoryProvider).currentUserId;
    if (!session.isUnlocked || session.dek == null || userId == null) {
      state = state.copyWith(
        items: [],
        folders: [],
        loading: false,
        hasLoaded: true,
      );
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _ref.read(vaultRepositoryProvider).listItems(
            userId: userId,
            dek: session.dek!,
          );
      final folders =
          await _ref.read(folderRepositoryProvider).listFolders(userId);
      state = state.copyWith(
        items: items,
        folders: folders,
        loading: false,
        hasLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        hasLoaded: true,
        error: await userFacingErrorMessage(
          _ref.read(connectivityServiceProvider),
          e,
        ),
      );
    }
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void setFilter(VaultItemType? type) {
    state = state.copyWith(filter: type, clearFilter: type == null);
  }

  Future<void> setSort(VaultSort sort) async {
    state = state.copyWith(sort: sort);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortKey, sort.name);
  }

  Future<void> delete(String id) async {
    await _ref.read(vaultRepositoryProvider).deleteItem(id);
    await refresh();
  }

  Future<VaultFolder?> createFolder(String name) async {
    final userId = _ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return null;
    final folder = await _ref.read(folderRepositoryProvider).createFolder(
          userId: userId,
          name: name,
        );
    await refresh();
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    await _ref.read(folderRepositoryProvider).renameFolder(id: id, name: name);
    await refresh();
  }

  Future<void> deleteFolder(String id) async {
    await _ref.read(folderRepositoryProvider).deleteFolder(id);
    await refresh();
  }
}

final vaultListProvider =
    StateNotifierProvider<VaultListNotifier, VaultListState>((ref) {
  return VaultListNotifier(ref);
});
