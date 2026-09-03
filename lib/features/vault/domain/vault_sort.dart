/// Home list sort. Applied within each folder section, not across sections.
enum VaultSort {
  nameAsc,
  nameDesc,
  updatedDesc,
  updatedAsc,
  createdDesc,
  createdAsc,
}

extension VaultSortX on VaultSort {
  String get label => switch (this) {
        VaultSort.nameAsc => 'Name · A → Z',
        VaultSort.nameDesc => 'Name · Z → A',
        VaultSort.updatedDesc => 'Updated · newest first',
        VaultSort.updatedAsc => 'Updated · oldest first',
        VaultSort.createdDesc => 'Created · newest first',
        VaultSort.createdAsc => 'Created · oldest first',
      };

  /// Icon for the sort picker; name vs recency vs created.
  String get icon => switch (this) {
        VaultSort.nameAsc || VaultSort.nameDesc => 'sort',
        VaultSort.updatedDesc || VaultSort.updatedAsc => 'timer',
        VaultSort.createdDesc || VaultSort.createdAsc => 'plus',
      };

  static VaultSort fromName(String? name) {
    return VaultSort.values.firstWhere(
      (e) => e.name == name,
      orElse: () => VaultSort.updatedDesc,
    );
  }
}
