import 'package:sembast/sembast.dart';

import '../offline_constants.dart';
import '../offline_models.dart';

/// Raw access to `ops_records` - the only copy of pending business data.
///
/// Workspace checks live in `LocalRecordRepository`; this DAO still filters
/// every read by `workspaceId` so a key collision can never leak a record
/// across workspaces.
class LocalRecordDao {
  LocalRecordDao(this._db);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store(OfflineStores.opsRecords);

  DatabaseClient _c(DatabaseClient? client) => client ?? _db;

  Future<LocalRecord?> get(
    String workspaceId,
    String entityType,
    String recordId, {
    DatabaseClient? client,
  }) async {
    final value = await _store
        .record(LocalRecord.keyOf(entityType, recordId))
        .get(_c(client));

    if (value == null) return null;

    final record = LocalRecord.fromMap(value);
    return record.workspaceId == workspaceId ? record : null;
  }

  Future<List<LocalRecord>> list(
    String workspaceId, {
    String? entityType,
    DatabaseClient? client,
  }) async {
    final snapshots = await _store.find(
      _c(client),
      finder: Finder(
        filter: Filter.and([
          Filter.equals('workspaceId', workspaceId),
          if (entityType != null) Filter.equals('entityType', entityType),
        ]),
        sortOrders: [SortOrder('createdAt')],
      ),
    );

    return snapshots.map((s) => LocalRecord.fromMap(s.value)).toList();
  }

  Future<void> put(LocalRecord record, {DatabaseClient? client}) async {
    await _store.record(record.key).put(_c(client), record.toMap());
  }

  Future<void> delete(
    String workspaceId,
    String entityType,
    String recordId, {
    DatabaseClient? client,
  }) async {
    final existing = await get(
      workspaceId,
      entityType,
      recordId,
      client: client,
    );

    if (existing == null) return;

    await _store.record(existing.key).delete(_c(client));
  }

  Future<int> count(String workspaceId, {DatabaseClient? client}) {
    return _store.count(
      _c(client),
      filter: Filter.equals('workspaceId', workspaceId),
    );
  }

  Future<int> deleteWorkspace(String workspaceId, {DatabaseClient? client}) {
    return _store.delete(
      _c(client),
      finder: Finder(filter: Filter.equals('workspaceId', workspaceId)),
    );
  }
}
