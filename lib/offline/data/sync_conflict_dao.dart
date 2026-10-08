import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../offline_constants.dart';
import '../offline_models.dart';

/// `sync_conflicts`: references and metadata only. The local and server
/// values are loaded on demand for the comparison screen.
class SyncConflictDao {
  SyncConflictDao(this._db);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store(OfflineStores.syncConflicts);

  DatabaseClient _c(DatabaseClient? client) => client ?? _db;

  /// Records a conflict. A record has at most one open conflict; a second
  /// detection updates the existing one instead of adding another.
  Future<SyncConflict> open({
    required String workspaceId,
    required String entityType,
    required String recordId,
    required String conflictType,
    String? detail,
    DatabaseClient? client,
  }) async {
    final existing = await findOpenFor(
      workspaceId,
      entityType,
      recordId,
      client: client,
    );

    if (existing != null) {
      final updated = existing.copyWith(
        conflictType: conflictType,
        detail: detail,
      );
      await _store.record(updated.conflictId).put(_c(client), updated.toMap());
      return updated;
    }

    final conflict = SyncConflict(
      conflictId: const Uuid().v4(),
      workspaceId: workspaceId,
      entityType: entityType,
      recordId: recordId,
      conflictType: conflictType,
      status: ConflictStatus.open,
      detectedAt: DateTime.now().toUtc(),
      detail: detail,
    );

    await _store.record(conflict.conflictId).put(_c(client), conflict.toMap());
    return conflict;
  }

  Future<SyncConflict?> findOpenFor(
    String workspaceId,
    String entityType,
    String recordId, {
    DatabaseClient? client,
  }) async {
    final snapshots = await _store.find(
      _c(client),
      finder: Finder(
        filter: Filter.and([
          Filter.equals('workspaceId', workspaceId),
          Filter.equals('entityType', entityType),
          Filter.equals('recordId', recordId),
          Filter.equals('status', ConflictStatus.open),
        ]),
      ),
    );

    if (snapshots.isEmpty) return null;
    return SyncConflict.fromMap(snapshots.first.value);
  }

  Future<SyncConflict?> get(
    String workspaceId,
    String conflictId, {
    DatabaseClient? client,
  }) async {
    final value = await _store.record(conflictId).get(_c(client));
    if (value == null) return null;

    final conflict = SyncConflict.fromMap(value);
    return conflict.workspaceId == workspaceId ? conflict : null;
  }

  Future<List<SyncConflict>> listOpen(
    String workspaceId, {
    DatabaseClient? client,
  }) async {
    final snapshots = await _store.find(
      _c(client),
      finder: Finder(
        filter: Filter.and([
          Filter.equals('workspaceId', workspaceId),
          Filter.equals('status', ConflictStatus.open),
        ]),
        sortOrders: [SortOrder('detectedAt')],
      ),
    );

    return snapshots.map((s) => SyncConflict.fromMap(s.value)).toList();
  }

  Future<int> countOpen(String workspaceId, {DatabaseClient? client}) {
    return _store.count(
      _c(client),
      filter: Filter.and([
        Filter.equals('workspaceId', workspaceId),
        Filter.equals('status', ConflictStatus.open),
      ]),
    );
  }

  Future<void> resolve(
    String workspaceId,
    String conflictId, {
    required String resolution,
    DatabaseClient? client,
  }) async {
    final conflict = await get(workspaceId, conflictId, client: client);
    if (conflict == null) return;

    final resolved = conflict.copyWith(
      status: ConflictStatus.resolved,
      resolvedAt: DateTime.now().toUtc(),
      resolution: resolution,
    );

    await _store.record(conflictId).put(_c(client), resolved.toMap());
  }

  Future<int> deleteWorkspace(String workspaceId, {DatabaseClient? client}) {
    return _store.delete(
      _c(client),
      finder: Finder(filter: Filter.equals('workspaceId', workspaceId)),
    );
  }
}
