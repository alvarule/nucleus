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
        VaultSort.nameAsc => 'Name A → Z',
        VaultSort.nameDesc => 'Name Z → A',
        VaultSort.updatedDesc => 'Recently updated',
        VaultSort.updatedAsc => 'Oldest updated',
        VaultSort.createdDesc => 'Recently created',
        VaultSort.createdAsc => 'Oldest created',
      };

  static VaultSort fromName(String? name) {
    return VaultSort.values.firstWhere(
      (e) => e.name == name,
      orElse: () => VaultSort.updatedDesc,
    );
  }
}
