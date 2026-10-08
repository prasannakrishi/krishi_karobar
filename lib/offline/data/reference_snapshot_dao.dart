import 'package:sembast/sembast.dart';

import '../offline_constants.dart';
import '../offline_exceptions.dart';
import '../offline_models.dart';

/// `ref_snapshot`: read-only reference data loaded while online (vehicle,
/// services, categories, recent activities...) so the UI keeps working
/// offline. It is replaceable at any time and is never a source of truth:
/// pending changes live in `ops_records`.
class ReferenceSnapshotDao {
  ReferenceSnapshotDao(this._db);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store(OfflineStores.refSnapshot);

  DatabaseClient _c(DatabaseClient? client) => client ?? _db;

  static String keyOf(String type, String recordId) => '$type|$recordId';

  Future<void> put({
    required String workspaceId,
    required String type,
    required String recordId,
    required Map<String, Object?> data,
    DatabaseClient? client,
  }) async {
    await _store.record(keyOf(type, recordId)).put(_c(client), {
      'workspaceId': workspaceId,
      'type': type,
      'recordId': recordId,
      'data': deepCopyMap(data),
      'loadedAt': nowUtcIso(),
    });
  }

  /// Replaces every snapshot of [type] for the workspace. Each record must
  /// carry a non-empty `id`.
  Future<void> replaceType({
    required String workspaceId,
    required String type,
    required List<Map<String, Object?>> records,
    DatabaseClient? client,
  }) {
    Future<void> run(DatabaseClient c) async {
      for (final record in records) {
        final id = record['id']?.toString().trim() ?? '';
        if (id.isEmpty) {
          throw OfflineDataException.invalid(
            message: 'Reference record of type "$type" has no id.',
          );
        }
      }

      await _store.delete(
        c,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('workspaceId', workspaceId),
            Filter.equals('type', type),
          ]),
        ),
      );

      for (final record in records) {
        await put(
          workspaceId: workspaceId,
          type: type,
          recordId: record['id']!.toString().trim(),
          data: record,
          client: c,
        );
      }
    }

    if (client != null) return run(client);
    return _db.transaction(run);
  }

  Future<Map<String, Object?>?> get(
    String workspaceId,
    String type,
    String recordId, {
    DatabaseClient? client,
  }) async {
    final value =
        await _store.record(keyOf(type, recordId)).get(_c(client));

    if (value == null || value['workspaceId'] != workspaceId) return null;

    final data = value['data'];
    return data is Map ? deepCopyMap(data) : null;
  }

  Future<List<Map<String, Object?>>> list(
    String workspaceId,
    String type, {
    DatabaseClient? client,
  }) async {
    final snapshots = await _store.find(
      _c(client),
      finder: Finder(
        filter: Filter.and([
          Filter.equals('workspaceId', workspaceId),
          Filter.equals('type', type),
        ]),
      ),
    );

    return [
      for (final snapshot in snapshots)
        if (snapshot.value['data'] is Map)
          deepCopyMap(snapshot.value['data']! as Map),
    ];
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
