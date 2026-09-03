/// Cloud vs device-only storage for vault items.
enum VaultSyncMode {
  cloud,
  local,
}

VaultSyncMode vaultSyncModeFromDb(String value) {
  return value == 'local' ? VaultSyncMode.local : VaultSyncMode.cloud;
}

String vaultSyncModeToDb(VaultSyncMode mode) =>
    mode == VaultSyncMode.local ? 'local' : 'cloud';
