import 'package:sembast/sembast.dart';

import '../data/reference_snapshot_dao.dart';
import '../offline_constants.dart';
import '../offline_exceptions.dart';
import '../offline_models.dart';
import 'record_index.dart';
import 'workspace_scope.dart';

/// Database version and migrations for the single offline Sembast database.
///
/// Version history
///  * 1 - original layout (one workspace per owner+vehicle, records keyed by
///    whatever entity spelling the caller used, snapshots keyed by
///    `users.id`).
///  * 2 - one workspace per environment+owner (`environment|owner`),
///    vehicle as a record-level indexed field, canonical entity and
///    reference types, flat index fields and tombstone fields on
///    `ops_records`, reference snapshots in the same workspace namespace.
///
/// Rollback: a migrated file cannot be opened by an older app version
/// (Sembast refuses a lower version) - restore the pre-upgrade copy of the
/// `kk_offline_<env>.db` file instead. The migration itself is atomic: if it
/// throws, nothing is changed and the app starts without offline storage
/// (see `OfflineStorage.initializationError`).
///
/// Migrations only add, re-key or re-home data. They never delete a
/// business record or queue entry, run in ONE transaction (any error rolls
/// everything back) and are safe to run twice.
class OfflineSchema {
  OfflineSchema._();

  static const int version = 2;

  /// Sembast `onVersionChanged` callback. [environment] names the database
  /// (`dev` / `prod`); it resolves v1 snapshots that were keyed by user id.
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion, {
    required String environment,
  }) async {
    // 0 = brand-new file: nothing to migrate. A newer file than this app
    // knows is left alone rather than risking its data.
    if (oldVersion == 0 || oldVersion >= newVersion) return;

    try {
      if (oldVersion < 2) await _v1ToV2(db, environment);
    } catch (error) {
      throw OfflineStorageException.migrationFailed(details: error);
    }
  }

  static final _ops = stringMapStoreFactory.store(OfflineStores.opsRecords);
  static final _queue = stringMapStoreFactory.store(OfflineStores.syncQueue);
  static final _conflicts =
      stringMapStoreFactory.store(OfflineStores.syncConflicts);
  static final _snapshots =
      stringMapStoreFactory.store(OfflineStores.refSnapshot);

  static Future<void> _v1ToV2(Database db, String environment) {
    return db.transaction((txn) async {
      for (final snap in await _ops.find(txn)) {
        await _migrateRecord(txn, snap.key, snap.value);
      }

      for (final snap in await _snapshots.find(txn)) {
        await _migrateSnapshot(txn, snap.key, snap.value, environment);
      }

      await _migrateWorkspaceMeta(txn);
    });
  }

  static Future<void> _migrateRecord(
    DatabaseClient txn,
    String oldKey,
    Map<String, Object?> value,
  ) async {
    final oldType = value['entityType']?.toString() ?? '';
    final recordId = value['recordId']?.toString() ?? '';
    if (oldType.isEmpty || recordId.isEmpty) return;

    final type = SyncEntity.canonical(oldType);
    final newKey = LocalRecord.keyOf(type, recordId);

    // Never overwrite a different record that already owns the new key.
    if (newKey != oldKey && await _ops.record(newKey).exists(txn)) return;

    final data = value['data'] is Map
        ? deepCopyMap(value['data']! as Map)
        : <String, Object?>{};

    final oldWorkspace = value['workspaceId']?.toString() ?? '';
    final workspace = _targetWorkspace(oldWorkspace);
    final scopeVehicle = _legacyVehicleOf(oldWorkspace);

    final index = LocalRecordIndex.derive(
      entityType: type,
      recordId: recordId,
      data: data,
      scopeVehicleId: scopeVehicle,
    );

    final migrated = Map<String, Object?>.from(value)
      ..['entityType'] = type
      ..['workspaceId'] = workspace
      // Keep a vehicle an earlier run (or the old workspace) supplied when
      // the record itself names none, so re-running is a no-op.
      ..['vehicleId'] = index.vehicleId.isNotEmpty
          ? index.vehicleId
          : (value['vehicleId']?.toString() ?? '')
      ..['customerId'] = index.customerId
      ..['recordStatus'] = index.status
      ..['ownerType'] = value['ownerType']?.toString() ?? ''
      ..['deletedAt'] = value['deletedAt']
      ..['isDeleted'] = value['deletedAt'] != null;

    await _ops.record(newKey).put(txn, migrated);
    if (newKey != oldKey) await _ops.record(oldKey).delete(txn);

    final queueValue = await _queue.record(oldKey).get(txn);
    if (queueValue != null) {
      final movedQueue = Map<String, Object?>.from(queueValue)
        ..['entityType'] = type
        ..['workspaceId'] = workspace
        ..['queueId'] = newKey;
      await _queue.record(newKey).put(txn, movedQueue);
      if (newKey != oldKey) await _queue.record(oldKey).delete(txn);
    }

    if (type != oldType || workspace != oldWorkspace) {
      final related = await _conflicts.find(
        txn,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('entityType', oldType),
            Filter.equals('recordId', recordId),
          ]),
        ),
      );
      for (final conflict in related) {
        await _conflicts.record(conflict.key).put(
              txn,
              Map<String, Object?>.from(conflict.value)
                ..['entityType'] = type
                ..['workspaceId'] = workspace,
            );
      }
    }
  }

  static Future<void> _migrateSnapshot(
    DatabaseClient txn,
    String oldKey,
    Map<String, Object?> value,
    String environment,
  ) async {
    final oldType = value['type']?.toString() ?? '';
    final recordId = value['recordId']?.toString() ?? '';
    if (oldType.isEmpty || recordId.isEmpty) return;

    final type = ReferenceType.canonical(oldType);
    final newKey = ReferenceSnapshotDao.keyOf(type, recordId);

    final oldWorkspace = value['workspaceId']?.toString() ?? '';
    // v1 snapshots were keyed by the bare user id (cache layer) or by the
    // old vehicle workspace id (engine).
    var workspace = _targetWorkspace(oldWorkspace);
    if (!oldWorkspace.contains('|') && oldWorkspace.isNotEmpty) {
      workspace = WorkspaceScope.idFor(environment, oldWorkspace);
    }

    final migrated = Map<String, Object?>.from(value)
      ..['type'] = type
      ..['workspaceId'] = workspace;

    if (newKey != oldKey) {
      final existing = await _snapshots.record(newKey).get(txn);
      final existingLoaded = existing?['loadedAt']?.toString() ?? '';
      final incomingLoaded = value['loadedAt']?.toString() ?? '';
      // Snapshots are replaceable copies of server data: keep the newer.
      if (existing == null || incomingLoaded.compareTo(existingLoaded) > 0) {
        await _snapshots.record(newKey).put(txn, migrated);
      }
      await _snapshots.record(oldKey).delete(txn);
    } else {
      await _snapshots.record(oldKey).put(txn, migrated);
    }
  }

  /// `environment|owner|vehicle` -> `environment|owner`. Anything not in
  /// that shape is left as it is (kept, counted as unsynced, never dropped).
  static String _targetWorkspace(String workspaceId) {
    final parts = workspaceId.split('|');
    if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return workspaceId;
    }
    return WorkspaceScope.idFor(parts[0], parts[1]);
  }

  /// The vehicle a v1 workspace was opened for, used as the record's
  /// vehicle only when the record itself names none. Placeholders are not
  /// vehicles.
  static String? _legacyVehicleOf(String workspaceId) {
    final parts = workspaceId.split('|');
    if (parts.length != 3) return null;
    final vehicle = parts[2];
    if (vehicle.isEmpty || vehicle == 'default' || vehicle == '_global') {
      return null;
    }
    return vehicle;
  }

  /// The single `current` workspace descriptor follows the new id; its
  /// vehicle field is dropped.
  static Future<void> _migrateWorkspaceMeta(DatabaseClient txn) async {
    final store = stringMapStoreFactory.store(OfflineStores.workspaceMeta);
    final current = await store.record('current').get(txn);
    if (current == null) return;

    final migrated = Map<String, Object?>.from(current)
      ..['workspaceId'] =
          _targetWorkspace(current['workspaceId']?.toString() ?? '')
      ..remove('vehicleId');
    await store.record('current').put(txn, migrated);
  }
}
