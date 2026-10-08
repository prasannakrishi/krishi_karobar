import 'package:sembast/sembast.dart';

import '../utils/constants/environment_config.dart';
import 'core/local_database.dart';
import 'data/local_record_dao.dart';
import 'data/local_record_repository.dart';
import 'data/local_sequence_dao.dart';
import 'data/reference_snapshot_dao.dart';
import 'data/sync_conflict_dao.dart';
import 'data/sync_queue_dao.dart';
import 'data/workspace_repository.dart';
import 'offline_exceptions.dart';

/// Single entry point to the offline workspace storage. Later stages (UID
/// service, sync engine, guards) reach the DAOs and repositories through
/// `OfflineStorage.instance`, the same pattern as `DataCacheService`.
class OfflineStorage {
  OfflineStorage._(this.local)
      : queue = SyncQueueDao(local.database),
        conflicts = SyncConflictDao(local.database),
        sequences = LocalSequenceDao(local.database),
        snapshots = ReferenceSnapshotDao(local.database),
        records = LocalRecordDao(local.database) {
    workspaces = WorkspaceRepository(
      database: local.database,
      records: records,
      queue: queue,
      conflicts: conflicts,
      snapshots: snapshots,
    );

    localRecords = LocalRecordRepository(
      database: local.database,
      workspaces: workspaces,
      records: records,
      queue: queue,
      conflicts: conflicts,
      snapshots: snapshots,
    );
  }

  static OfflineStorage? _instance;

  final LocalDatabase local;
  final SyncQueueDao queue;
  final SyncConflictDao conflicts;
  final LocalSequenceDao sequences;
  final ReferenceSnapshotDao snapshots;
  final LocalRecordDao records;
  late final WorkspaceRepository workspaces;
  late final LocalRecordRepository localRecords;

  Database get database => local.database;

  static bool get isAvailable => _instance != null;

  static OfflineStorage get instance {
    final storage = _instance;
    if (storage == null) throw const OfflineStorageException.unavailable();
    return storage;
  }

  /// Opens the database for the running environment. Called once at app
  /// start; safe to call again (returns the open instance).
  static Future<OfflineStorage> initialize() async {
    final existing = _instance;
    if (existing != null) return existing;

    try {
      final local = await LocalDatabase.open(
        environmentName: EnvironmentConfig.currentEnvironment.name,
      );
      return _instance = OfflineStorage._(local);
    } catch (error) {
      throw OfflineStorageException.unavailable(details: error);
    }
  }

  /// Storage over an already opened database (tests). Does not replace
  /// [instance].
  static OfflineStorage forDatabase(Database database) {
    return OfflineStorage._(LocalDatabase.fromDatabase(database));
  }

  Future<void> close() async {
    await local.close();
    if (identical(_instance, this)) _instance = null;
  }
}
