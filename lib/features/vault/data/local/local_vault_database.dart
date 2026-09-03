/// Opens the on-device Drift database for local-only vault items.
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:nucleus/features/vault/data/local/local_vault_tables.dart';

part 'local_vault_database.g.dart';

@DriftDatabase(tables: [LocalVaultItems])
class LocalVaultDatabase extends _$LocalVaultDatabase {
  LocalVaultDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'nucleus_local_vault');
  }
}
