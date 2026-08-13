import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';

class VaultListState {
  const VaultListState({
    this.items = const [],
    this.loading = false,
    this.query = '',
    this.filter,
    this.error,
  });

  final List<VaultItem> items;
  final bool loading;
  final String query;
  final VaultItemType? filter;
  final String? error;

  List<VaultItem> get visible {
    return items.where((item) {
      if (filter != null && item.type != filter) return false;
      if (query.trim().isEmpty) return true;
      final q = query.toLowerCase();
      return item.label.toLowerCase().contains(q) ||
          item.fields.values.any((v) => '$v'.toLowerCase().contains(q));
    }).toList();
  }

  VaultListState copyWith({
    List<VaultItem>? items,
    bool? loading,
    String? query,
    VaultItemType? filter,
    String? error,
    bool clearFilter = false,
    bool clearError = false,
  }) {
    return VaultListState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      query: query ?? this.query,
      filter: clearFilter ? null : (filter ?? this.filter),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VaultListNotifier extends StateNotifier<VaultListState> {
  VaultListNotifier(this._ref) : super(const VaultListState());

  final Ref _ref;

  Future<void> refresh() async {
    final session = _ref.read(vaultSessionProvider);
    final userId = _ref.read(authRepositoryProvider).currentUserId;
    if (!session.isUnlocked || session.dek == null || userId == null) {
      state = state.copyWith(items: [], loading: false);
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _ref.read(vaultRepositoryProvider).listItems(
            userId: userId,
            dek: session.dek!,
          );
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void setFilter(VaultItemType? type) {
    state = state.copyWith(filter: type, clearFilter: type == null);
  }

  Future<void> delete(String id) async {
    await _ref.read(vaultRepositoryProvider).deleteItem(id);
    await refresh();
  }
}

final vaultListProvider =
    StateNotifierProvider<VaultListNotifier, VaultListState>((ref) {
  return VaultListNotifier(ref);
});
