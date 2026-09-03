// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_vault_database.dart';

// ignore_for_file: type=lint
class $LocalVaultItemsTable extends LocalVaultItems
    with TableInfo<$LocalVaultItemsTable, LocalVaultItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalVaultItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<String> encryptedPayload = GeneratedColumn<String>(
    'encrypted_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nonceMeta = const VerificationMeta('nonce');
  @override
  late final GeneratedColumn<String> nonce = GeneratedColumn<String>(
    'nonce',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    itemType,
    folderId,
    encryptedPayload,
    nonce,
    createdAtMs,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_vault_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalVaultItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadMeta);
    }
    if (data.containsKey('nonce')) {
      context.handle(
        _nonceMeta,
        nonce.isAcceptableOrUnknown(data['nonce']!, _nonceMeta),
      );
    } else if (isInserting) {
      context.missing(_nonceMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalVaultItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalVaultItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_payload'],
      )!,
      nonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nonce'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $LocalVaultItemsTable createAlias(String alias) {
    return $LocalVaultItemsTable(attachedDatabase, alias);
  }
}

class LocalVaultItem extends DataClass implements Insertable<LocalVaultItem> {
  final String id;
  final String userId;
  final String itemType;
  final String? folderId;
  final String encryptedPayload;
  final String nonce;
  final int createdAtMs;
  final int updatedAtMs;
  const LocalVaultItem({
    required this.id,
    required this.userId,
    required this.itemType,
    this.folderId,
    required this.encryptedPayload,
    required this.nonce,
    required this.createdAtMs,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['item_type'] = Variable<String>(itemType);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['encrypted_payload'] = Variable<String>(encryptedPayload);
    map['nonce'] = Variable<String>(nonce);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  LocalVaultItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalVaultItemsCompanion(
      id: Value(id),
      userId: Value(userId),
      itemType: Value(itemType),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      encryptedPayload: Value(encryptedPayload),
      nonce: Value(nonce),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory LocalVaultItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalVaultItem(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      itemType: serializer.fromJson<String>(json['itemType']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      encryptedPayload: serializer.fromJson<String>(json['encryptedPayload']),
      nonce: serializer.fromJson<String>(json['nonce']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'itemType': serializer.toJson<String>(itemType),
      'folderId': serializer.toJson<String?>(folderId),
      'encryptedPayload': serializer.toJson<String>(encryptedPayload),
      'nonce': serializer.toJson<String>(nonce),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  LocalVaultItem copyWith({
    String? id,
    String? userId,
    String? itemType,
    Value<String?> folderId = const Value.absent(),
    String? encryptedPayload,
    String? nonce,
    int? createdAtMs,
    int? updatedAtMs,
  }) => LocalVaultItem(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    itemType: itemType ?? this.itemType,
    folderId: folderId.present ? folderId.value : this.folderId,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    nonce: nonce ?? this.nonce,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  LocalVaultItem copyWithCompanion(LocalVaultItemsCompanion data) {
    return LocalVaultItem(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
      nonce: data.nonce.present ? data.nonce.value : this.nonce,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalVaultItem(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('itemType: $itemType, ')
          ..write('folderId: $folderId, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('nonce: $nonce, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    itemType,
    folderId,
    encryptedPayload,
    nonce,
    createdAtMs,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalVaultItem &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.itemType == this.itemType &&
          other.folderId == this.folderId &&
          other.encryptedPayload == this.encryptedPayload &&
          other.nonce == this.nonce &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs);
}

class LocalVaultItemsCompanion extends UpdateCompanion<LocalVaultItem> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> itemType;
  final Value<String?> folderId;
  final Value<String> encryptedPayload;
  final Value<String> nonce;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const LocalVaultItemsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.folderId = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.nonce = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalVaultItemsCompanion.insert({
    required String id,
    required String userId,
    required String itemType,
    this.folderId = const Value.absent(),
    required String encryptedPayload,
    required String nonce,
    required int createdAtMs,
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       itemType = Value(itemType),
       encryptedPayload = Value(encryptedPayload),
       nonce = Value(nonce),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<LocalVaultItem> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? itemType,
    Expression<String>? folderId,
    Expression<String>? encryptedPayload,
    Expression<String>? nonce,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (itemType != null) 'item_type': itemType,
      if (folderId != null) 'folder_id': folderId,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (nonce != null) 'nonce': nonce,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalVaultItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? itemType,
    Value<String?>? folderId,
    Value<String>? encryptedPayload,
    Value<String>? nonce,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return LocalVaultItemsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemType: itemType ?? this.itemType,
      folderId: folderId ?? this.folderId,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      nonce: nonce ?? this.nonce,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<String>(encryptedPayload.value);
    }
    if (nonce.present) {
      map['nonce'] = Variable<String>(nonce.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalVaultItemsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('itemType: $itemType, ')
          ..write('folderId: $folderId, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('nonce: $nonce, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalVaultDatabase extends GeneratedDatabase {
  _$LocalVaultDatabase(QueryExecutor e) : super(e);
  $LocalVaultDatabaseManager get managers => $LocalVaultDatabaseManager(this);
  late final $LocalVaultItemsTable localVaultItems = $LocalVaultItemsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [localVaultItems];
}

typedef $$LocalVaultItemsTableCreateCompanionBuilder =
    LocalVaultItemsCompanion Function({
      required String id,
      required String userId,
      required String itemType,
      Value<String?> folderId,
      required String encryptedPayload,
      required String nonce,
      required int createdAtMs,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$LocalVaultItemsTableUpdateCompanionBuilder =
    LocalVaultItemsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> itemType,
      Value<String?> folderId,
      Value<String> encryptedPayload,
      Value<String> nonce,
      Value<int> createdAtMs,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

class $$LocalVaultItemsTableFilterComposer
    extends Composer<_$LocalVaultDatabase, $LocalVaultItemsTable> {
  $$LocalVaultItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalVaultItemsTableOrderingComposer
    extends Composer<_$LocalVaultDatabase, $LocalVaultItemsTable> {
  $$LocalVaultItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalVaultItemsTableAnnotationComposer
    extends Composer<_$LocalVaultDatabase, $LocalVaultItemsTable> {
  $$LocalVaultItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nonce =>
      $composableBuilder(column: $table.nonce, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$LocalVaultItemsTableTableManager
    extends
        RootTableManager<
          _$LocalVaultDatabase,
          $LocalVaultItemsTable,
          LocalVaultItem,
          $$LocalVaultItemsTableFilterComposer,
          $$LocalVaultItemsTableOrderingComposer,
          $$LocalVaultItemsTableAnnotationComposer,
          $$LocalVaultItemsTableCreateCompanionBuilder,
          $$LocalVaultItemsTableUpdateCompanionBuilder,
          (
            LocalVaultItem,
            BaseReferences<
              _$LocalVaultDatabase,
              $LocalVaultItemsTable,
              LocalVaultItem
            >,
          ),
          LocalVaultItem,
          PrefetchHooks Function()
        > {
  $$LocalVaultItemsTableTableManager(
    _$LocalVaultDatabase db,
    $LocalVaultItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalVaultItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalVaultItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalVaultItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String> encryptedPayload = const Value.absent(),
                Value<String> nonce = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalVaultItemsCompanion(
                id: id,
                userId: userId,
                itemType: itemType,
                folderId: folderId,
                encryptedPayload: encryptedPayload,
                nonce: nonce,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String itemType,
                Value<String?> folderId = const Value.absent(),
                required String encryptedPayload,
                required String nonce,
                required int createdAtMs,
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => LocalVaultItemsCompanion.insert(
                id: id,
                userId: userId,
                itemType: itemType,
                folderId: folderId,
                encryptedPayload: encryptedPayload,
                nonce: nonce,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalVaultItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalVaultDatabase,
      $LocalVaultItemsTable,
      LocalVaultItem,
      $$LocalVaultItemsTableFilterComposer,
      $$LocalVaultItemsTableOrderingComposer,
      $$LocalVaultItemsTableAnnotationComposer,
      $$LocalVaultItemsTableCreateCompanionBuilder,
      $$LocalVaultItemsTableUpdateCompanionBuilder,
      (
        LocalVaultItem,
        BaseReferences<
          _$LocalVaultDatabase,
          $LocalVaultItemsTable,
          LocalVaultItem
        >,
      ),
      LocalVaultItem,
      PrefetchHooks Function()
    >;

class $LocalVaultDatabaseManager {
  final _$LocalVaultDatabase _db;
  $LocalVaultDatabaseManager(this._db);
  $$LocalVaultItemsTableTableManager get localVaultItems =>
      $$LocalVaultItemsTableTableManager(_db, _db.localVaultItems);
}
