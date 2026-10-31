import 'package:sembast/sembast.dart';

import '../core/workspace_scope.dart';
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
        .record(LocalRecord.keyOf(SyncEntity.canonical(entityType), recordId))
        .get(_c(client));

    if (value == null) return null;

    final record = LocalRecord.fromMap(value);
    return record.workspaceId == workspaceId ? record : null;
  }

  /// Workspace that currently holds this record, whichever it is. Record
  /// keys are `entityType|recordId` (not per workspace), so a writer must
  /// know whether the key is already taken by another workspace.
  Future<String?> workspaceOf(
    String entityType,
    String recordId, {
    DatabaseClient? client,
  }) async {
    final value = await _store
        .record(LocalRecord.keyOf(SyncEntity.canonical(entityType), recordId))
        .get(_c(client));
    return value?['workspaceId']?.toString();
  }

  /// Records of one workspace, oldest first. The optional filters run on
  /// the flat index fields (`entityType`, `vehicleId`, `customerId`,
  /// `recordStatus`, `isDeleted`).
  Future<List<LocalRecord>> list(
    String workspaceId, {
    String? entityType,
    String? vehicleId,
    String? customerId,
    String? status,
    bool includeDeleted = true,
    DatabaseClient? client,
  }) async {
    final snapshots = await _store.find(
      _c(client),
      finder: Finder(
        filter: Filter.and([
          Filter.equals('workspaceId', workspaceId),
          if (entityType != null)
            Filter.equals('entityType', SyncEntity.canonical(entityType)),
          if (vehicleId != null) Filter.equals('vehicleId', vehicleId),
          if (customerId != null) Filter.equals('customerId', customerId),
          if (status != null) Filter.equals('recordStatus', status),
          if (!includeDeleted) Filter.equals('isDeleted', false),
        ]),
        sortOrders: [SortOrder('createdAt')],
      ),
    );

    return snapshots.map((s) => LocalRecord.fromMap(s.value)).toList();
  }

  /// Locally deleted records whose deletion is not synchronized yet. Remote
  /// refreshes must treat these ids as gone, never restore them.
  Future<List<LocalRecord>> listTombstones(
    String workspaceId, {
    DatabaseClient? client,
  }) async {
    final snapshots = await _store.find(
      _c(client),
      finder: Finder(
        filter: Filter.and([
          Filter.equals('workspaceId', workspaceId),
          Filter.equals('isDeleted', true),
        ]),
        sortOrders: [SortOrder('createdAt')],
      ),
    );

    return snapshots.map((s) => LocalRecord.fromMap(s.value)).toList();
  }

  /// Every workspace id of one owner that currently holds records (vehicle
  /// workspaces, the global workspace and any legacy one). Matches the
  /// exact `environment|owner|vehicle` shape - never a substring.
  Future<Set<String>> workspaceIdsForOwner(
    String ownerUserId, {
    String? environment,
    DatabaseClient? client,
  }) async {
    final snapshots = await _store.find(_c(client));
    final ids = <String>{};

    for (final snapshot in snapshots) {
      final id = snapshot.value['workspaceId']?.toString() ?? '';
      if (_belongsTo(id, ownerUserId, environment)) ids.add(id);
    }

    return ids;
  }

  /// All records of one owner across the owner's workspaces.
  Future<List<LocalRecord>> listAllForOwner(
    String ownerUserId, {
    String? entityType,
    String? environment,
    bool includeDeleted = true,
    DatabaseClient? client,
  }) async {
    final filters = <Filter>[
      if (entityType != null)
        Filter.equals('entityType', SyncEntity.canonical(entityType)),
      if (!includeDeleted) Filter.equals('isDeleted', false),
    ];

    final snapshots = await _store.find(
      _c(client),
      finder: Finder(
        filter: filters.isEmpty ? null : Filter.and(filters),
        sortOrders: [SortOrder('createdAt')],
      ),
    );

    return snapshots
        .map((s) => LocalRecord.fromMap(s.value))
        .where((r) => _belongsTo(r.workspaceId, ownerUserId, environment))
        .toList();
  }

  static bool _belongsTo(
    String workspaceId,
    String ownerUserId,
    String? environment,
  ) {
    if (WorkspaceScope.ownerOf(workspaceId) != ownerUserId) return false;
    return environment == null ||
        WorkspaceScope.environmentOf(workspaceId) == environment;
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
