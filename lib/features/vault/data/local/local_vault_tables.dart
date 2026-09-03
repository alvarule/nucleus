/// Drift schema for local-only vault rows (encrypted payloads mirror cloud shape).
import 'package:drift/drift.dart';

class LocalVaultItems extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get itemType => text()();
  TextColumn get folderId => text().nullable()();
  TextColumn get encryptedPayload => text()();
  TextColumn get nonce => text()();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
