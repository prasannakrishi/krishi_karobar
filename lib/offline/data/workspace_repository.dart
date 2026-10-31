import 'package:sembast/sembast.dart';

import '../core/workspace_access.dart';
import '../core/workspace_scope.dart';
import '../offline_constants.dart';
import '../offline_exceptions.dart';
import '../offline_models.dart';
import 'local_record_dao.dart';
import 'reference_snapshot_dao.dart';
import 'sync_conflict_dao.dart';
import 'sync_queue_dao.dart';

/// Owns the offline workspace on this device: ONE per environment and
/// owner. While it holds unsynchronized data it can only be re-opened by the
/// same owner (same auth identity), which prevents cross-user mixing.
/// Vehicles are not workspaces - a record carries its own `vehicleId` and
/// the stored [WorkspaceAccess] decides which vehicles the owner may use.
class WorkspaceRepository {
  WorkspaceRepository({
    required Database database,
    required LocalRecordDao records,
    required SyncQueueDao queue,
    required SyncConflictDao conflicts,
    required ReferenceSnapshotDao snapshots,
  })  : _db = database,
        _records = records,
        _queue = queue,
        _conflicts = conflicts,
        _snapshots = snapshots;

  static const String _key = 'current';

  final Database _db;
  final LocalRecordDao _records;
  final SyncQueueDao _queue;
  final SyncConflictDao _conflicts;
  final ReferenceSnapshotDao _snapshots;

  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store(OfflineStores.workspaceMeta);

  DatabaseClient _c(DatabaseClient? client) => client ?? _db;

  /// Digits only, without the +977 country code, so "+9779812345678" and
  /// "9812345678" compare equal.
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('977') && digits.length > 10) {
      return digits.substring(3);
    }
    return digits;
  }

  Future<WorkspaceInfo?> current({DatabaseClient? client}) async {
    final value = await _store.record(_key).get(_c(client));
    return value == null ? null : WorkspaceInfo.fromMap(value);
  }

  /// Opens (or re-activates) the workspace for [scope].
  ///
  /// * none exists          -> create it
  /// * same owner           -> re-activate (owner returning, or the
  ///   access profile refreshed after a vehicle assignment change)
  /// * different owner      -> refused while the old owner has
  ///   unsynchronized data; wiped and replaced only when completely clean.
  Future<WorkspaceInfo> open(
    WorkspaceScope scope, {
    required String ownerPhone,
    WorkspaceAccess? access,
  }) {
    scope.validate();

    return _db.transaction((txn) async {
      final now = DateTime.now().toUtc();
      final existing = await current(client: txn);

      if (existing != null) {
        if (existing.workspaceId == scope.workspaceId) {
          if (existing.authUid != scope.authUid &&
              !(await ownerCounts(existing, client: txn)).isClean) {
            throw const WorkspaceOwnershipException.differentAuthIdentity();
          }

          final reopened = existing.copyWith(
            authUid: scope.authUid,
            ownerPhone: normalizePhone(ownerPhone),
            state: WorkspaceState.active,
            updatedAt: now,
            access: access,
          );
          await _put(reopened, txn);
          return reopened;
        }

        if (!(await ownerCounts(existing, client: txn)).isClean) {
          throw const WorkspaceOwnershipException.differentOwner();
        }
        await _wipeOwner(existing, txn);
      }

      final created = WorkspaceInfo(
        access: access,
        workspaceId: scope.workspaceId,
        environment: scope.environment,
        ownerUserId: scope.ownerUserId,
        authUid: scope.authUid,
        ownerPhone: normalizePhone(ownerPhone),
        state: WorkspaceState.active,
        createdAt: now,
        updatedAt: now,
      );

      await _put(created, txn);
      return created;
    });
  }

  /// Session ended but data remains: keep everything, stop accepting new
  /// records. The owner's Firebase sign-in is kept by the session layer so
  /// sync can continue.
  Future<void> lock() async {
    await _db.transaction((txn) async {
      final info = await current(client: txn);
      if (info == null || info.isLocked) return;

      await _put(
        info.copyWith(
          state: WorkspaceState.locked,
          updatedAt: DateTime.now().toUtc(),
        ),
        txn,
      );
    });
  }

  Future<WorkspaceCounts> counts(
    String workspaceId, {
    DatabaseClient? client,
  }) async {
    final byStatus = await _queue.countsByStatus(workspaceId, client: client);
    final queueTotal = await _queue.total(workspaceId, client: client);
    final recordCount = await _records.count(workspaceId, client: client);
    final openConflicts = await _conflicts.countOpen(
      workspaceId,
      client: client,
    );

    final queuedConflicts = byStatus[QueueStatus.conflict] ?? 0;

    return WorkspaceCounts(
      pending: (byStatus[QueueStatus.pending] ?? 0) +
          (byStatus[QueueStatus.syncing] ?? 0) +
          (byStatus[QueueStatus.blocked] ?? 0),
      failed: byStatus[QueueStatus.failed] ?? 0,
      conflicts: openConflicts > queuedConflicts
          ? openConflicts
          : queuedConflicts,
      orphanRecords: recordCount > queueTotal ? recordCount - queueTotal : 0,
    );
  }

  /// Counts for the current workspace, or an empty (clean) result when no
  /// workspace exists.
  Future<WorkspaceCounts> currentCounts() async {
    final info = await current();
    if (info == null) return const WorkspaceCounts();
    return ownerCounts(info);
  }

  /// Sync health of everything the open workspace's owner has on this
  /// device: the workspace itself plus any other workspace id that still
  /// holds records (a pre-v2 `environment|owner|vehicle` one that migration
  /// could not re-home is kept and counted, never dropped). This is what
  /// pending counts and the logout/login guards use.
  Future<WorkspaceCounts> ownerCounts(
    WorkspaceInfo info, {
    DatabaseClient? client,
  }) async {
    var total = const WorkspaceCounts();
    for (final id in await _ownerWorkspaceIds(info, client)) {
      total = total + await counts(id, client: client);
    }
    return total;
  }

  Future<Set<String>> _ownerWorkspaceIds(
    WorkspaceInfo info,
    DatabaseClient? client,
  ) async {
    return {
      info.workspaceId,
      ...await _records.workspaceIdsForOwner(
        info.ownerUserId,
        environment: info.environment,
        client: client,
      ),
    };
  }

  Future<bool> isDirty() async => !(await currentCounts()).isClean;

  /// Whether the typed [phone] belongs to the workspace owner. `null` when
  /// there is no workspace. The login guard calls this BEFORE any Firebase
  /// sign-in, so a different user can never replace the owner's identity
  /// while unsynchronized data exists.
  Future<bool?> ownerMatchesPhone(String phone) async {
    final info = await current();
    if (info == null) return null;
    return info.ownerPhone == normalizePhone(phone);
  }

  /// Clears the workspace ONLY when pending, failed, conflicts and orphan
  /// records are all zero. Returns `false` (and keeps everything) otherwise.
  /// Local sequences are never cleared.
  Future<bool> clearIfClean() {
    return _db.transaction((txn) async {
      final info = await current(client: txn);
      if (info == null) return true;

      final health = await ownerCounts(info, client: txn);
      if (!health.isClean) return false;

      await _wipeOwner(info, txn);
      return true;
    });
  }

  Future<bool> _isDirty(String workspaceId, DatabaseClient client) async {
    return !(await counts(workspaceId, client: client)).isClean;
  }

  Future<void> _put(WorkspaceInfo info, DatabaseClient client) async {
    await _store.record(_key).put(client, info.toMap());
  }

  Future<void> _wipeData(String workspaceId, DatabaseClient client) async {
    await _records.deleteWorkspace(workspaceId, client: client);
    await _queue.deleteWorkspace(workspaceId, client: client);
    await _conflicts.deleteWorkspace(workspaceId, client: client);
    await _snapshots.deleteWorkspace(workspaceId, client: client);
  }

  /// Wipes every workspace of the owner. Callers verify the owner is clean
  /// first; local sequences are never touched.
  Future<void> _wipeOwner(WorkspaceInfo info, DatabaseClient client) async {
    for (final id in await _ownerWorkspaceIds(info, client)) {
      await _wipeData(id, client);
    }
    await _store.record(_key).delete(client);
  }
}
