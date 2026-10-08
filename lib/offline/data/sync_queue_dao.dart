import 'package:sembast/sembast.dart';

import '../offline_constants.dart';
import '../offline_models.dart';

/// `sync_queue`: one entry per record, holding a reference only. The record
/// data stays in `ops_records`, so the queue is never a second copy.
class SyncQueueDao {
  SyncQueueDao(this._db);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store(OfflineStores.syncQueue);

  DatabaseClient _c(DatabaseClient? client) => client ?? _db;

  Future<SyncQueueEntry?> get(
    String workspaceId,
    String entityType,
    String recordId, {
    DatabaseClient? client,
  }) async {
    final value = await _store
        .record(LocalRecord.keyOf(entityType, recordId))
        .get(_c(client));

    if (value == null) return null;

    final entry = SyncQueueEntry.fromMap(value);
    return entry.workspaceId == workspaceId ? entry : null;
  }

  Future<List<SyncQueueEntry>> list(
    String workspaceId, {
    List<String>? statuses,
    DatabaseClient? client,
  }) async {
    final snapshots = await _store.find(
      _c(client),
      finder: Finder(
        filter: Filter.and([
          Filter.equals('workspaceId', workspaceId),
          if (statuses != null) Filter.inList('status', statuses),
        ]),
        sortOrders: [SortOrder('createdAt')],
      ),
    );

    return snapshots.map((s) => SyncQueueEntry.fromMap(s.value)).toList();
  }

  /// Pending entries whose retry time has arrived, oldest first.
  Future<List<SyncQueueEntry>> nextRunnable(
    String workspaceId,
    DateTime now, {
    DatabaseClient? client,
  }) async {
    final pending = await list(
      workspaceId,
      statuses: const [QueueStatus.pending],
      client: client,
    );

    return pending
        .where((e) => e.nextAttemptAt == null || !e.nextAttemptAt!.isAfter(now))
        .toList();
  }

  Future<Map<String, int>> countsByStatus(
    String workspaceId, {
    DatabaseClient? client,
  }) async {
    final counts = <String, int>{};

    for (final entry in await list(workspaceId, client: client)) {
      counts[entry.status] = (counts[entry.status] ?? 0) + 1;
    }

    return counts;
  }

  Future<int> total(String workspaceId, {DatabaseClient? client}) {
    return _store.count(
      _c(client),
      filter: Filter.equals('workspaceId', workspaceId),
    );
  }

  /// Called inside the same transaction as the record save.
  ///
  /// * No entry yet: create one (`create` for a never-synced record,
  ///   otherwise `update`).
  /// * Entry exists: keep it (a create stays a create across edits); a
  ///   failed/blocked entry goes back to pending so the new data is
  ///   retried; a conflict or in-flight entry keeps its status.
  Future<SyncQueueEntry> upsertForSave({
    required String workspaceId,
    required String entityType,
    required String recordId,
    required bool isNew,
    DatabaseClient? client,
  }) async {
    final existing = await get(
      workspaceId,
      entityType,
      recordId,
      client: client,
    );

    if (existing == null) {
      final entry = SyncQueueEntry(
        workspaceId: workspaceId,
        entityType: entityType,
        recordId: recordId,
        operation: isNew ? SyncOperation.create : SyncOperation.update,
        status: QueueStatus.pending,
        attemptCount: 0,
        createdAt: DateTime.now().toUtc(),
      );
      await _put(entry, client);
      return entry;
    }

    final reopen = existing.status == QueueStatus.failed ||
        existing.status == QueueStatus.blocked;

    if (!reopen) return existing;

    final updated = existing.copyWith(
      status: QueueStatus.pending,
      clearNextAttemptAt: true,
    );
    await _put(updated, client);
    return updated;
  }

  Future<void> markSyncing(
    String workspaceId,
    String entityType,
    String recordId, {
    DatabaseClient? client,
  }) {
    return _update(workspaceId, entityType, recordId, client, (entry) {
      return entry.copyWith(
        status: QueueStatus.syncing,
        lastAttemptAt: DateTime.now().toUtc(),
        clearNextAttemptAt: true,
      );
    });
  }

  /// Retryable failure (network/server): stays pending, runs again after
  /// [retryAfter]. The attempt counter increments.
  Future<void> markRetryLater(
    String workspaceId,
    String entityType,
    String recordId, {
    required String category,
    required String message,
    required Duration retryAfter,
    DatabaseClient? client,
  }) {
    return _update(workspaceId, entityType, recordId, client, (entry) {
      final now = DateTime.now().toUtc();
      return entry.copyWith(
        status: QueueStatus.pending,
        attemptCount: entry.attemptCount + 1,
        lastAttemptAt: now,
        nextAttemptAt: now.add(retryAfter),
        lastError: message,
        lastErrorCategory: category,
      );
    });
  }

  /// Non-retryable failure (permission/validation) or retries exhausted:
  /// needs the user to press Retry.
  Future<void> markFailed(
    String workspaceId,
    String entityType,
    String recordId, {
    required String category,
    required String message,
    DatabaseClient? client,
  }) {
    return _update(workspaceId, entityType, recordId, client, (entry) {
      return entry.copyWith(
        status: QueueStatus.failed,
        attemptCount: entry.attemptCount + 1,
        lastAttemptAt: DateTime.now().toUtc(),
        clearNextAttemptAt: true,
        lastError: message,
        lastErrorCategory: category,
      );
    });
  }

  Future<void> markBlocked(
    String workspaceId,
    String entityType,
    String recordId, {
    required String message,
    DatabaseClient? client,
  }) {
    return _update(workspaceId, entityType, recordId, client, (entry) {
      return entry.copyWith(
        status: QueueStatus.blocked,
        lastError: message,
      );
    });
  }

  Future<void> markConflict(
    String workspaceId,
    String entityType,
    String recordId, {
    required String message,
    DatabaseClient? client,
  }) {
    return _update(workspaceId, entityType, recordId, client, (entry) {
      return entry.copyWith(
        status: QueueStatus.conflict,
        lastAttemptAt: DateTime.now().toUtc(),
        clearNextAttemptAt: true,
        lastError: message,
        lastErrorCategory: SyncErrorCategory.dataConflict,
      );
    });
  }

  Future<void> markUidClaimed(
    String workspaceId,
    String entityType,
    String recordId, {
    DatabaseClient? client,
  }) {
    return _update(workspaceId, entityType, recordId, client, (entry) {
      return entry.copyWith(uidClaimed: true);
    });
  }

  /// Puts an entry back to pending with a clean slate (conflict resolved,
  /// manual retry, parent became available).
  Future<void> resetToPending(
    String workspaceId,
    String entityType,
    String recordId, {
    String? operation,
    bool resetAttempts = false,
    DatabaseClient? client,
  }) {
    return _update(workspaceId, entityType, recordId, client, (entry) {
      return entry.copyWith(
        operation: operation,
        status: QueueStatus.pending,
        attemptCount: resetAttempts ? 0 : entry.attemptCount,
        clearNextAttemptAt: true,
        clearError: true,
      );
    });
  }

  /// Manual "Retry Failed": every failed entry goes back to pending.
  Future<int> retryFailed(String workspaceId, {DatabaseClient? client}) async {
    final failed = await list(
      workspaceId,
      statuses: const [QueueStatus.failed],
      client: client,
    );

    for (final entry in failed) {
      await resetToPending(
        workspaceId,
        entry.entityType,
        entry.recordId,
        client: client,
      );
    }

    return failed.length;
  }

  /// Startup recovery: an entry left in `syncing` means the app stopped
  /// mid-sync. It is safe to run again because create is idempotent
  /// (existing id with identical data counts as already synced).
  Future<int> resetSyncingToPending(
    String workspaceId, {
    DatabaseClient? client,
  }) async {
    final stuck = await list(
      workspaceId,
      statuses: const [QueueStatus.syncing],
      client: client,
    );

    for (final entry in stuck) {
      await _put(
        entry.copyWith(
          status: QueueStatus.pending,
          clearNextAttemptAt: true,
        ),
        client,
      );
    }

    return stuck.length;
  }

  Future<void> remove(
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

    await _store.record(existing.queueId).delete(_c(client));
  }

  Future<int> deleteWorkspace(String workspaceId, {DatabaseClient? client}) {
    return _store.delete(
      _c(client),
      finder: Finder(filter: Filter.equals('workspaceId', workspaceId)),
    );
  }

  Future<void> _put(SyncQueueEntry entry, DatabaseClient? client) async {
    await _store.record(entry.queueId).put(_c(client), entry.toMap());
  }

  Future<void> _update(
    String workspaceId,
    String entityType,
    String recordId,
    DatabaseClient? client,
    SyncQueueEntry Function(SyncQueueEntry entry) change,
  ) async {
    final existing = await get(
      workspaceId,
      entityType,
      recordId,
      client: client,
    );

    if (existing == null) return;

    await _put(change(existing), client);
  }
}
