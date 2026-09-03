/// Outcome of a settings-driven bulk local/cloud sync operation.
class VaultBulkSyncResult {
  const VaultBulkSyncResult({
    required this.succeeded,
    required this.failed,
    required this.skipped,
  });

  final int succeeded;
  final int failed;

  /// Items skipped because they were already in the target store (e.g. already in cloud).
  final int skipped;

  bool get hasFailures => failed > 0;
}
