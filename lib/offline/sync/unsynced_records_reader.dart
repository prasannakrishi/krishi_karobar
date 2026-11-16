import 'dart:async';

import '../offline_constants.dart';
import '../offline_models.dart';
import '../offline_storage.dart';
import 'sync_adapter.dart';

/// One unsynced record as shown to the admin. Built only from the local
/// queue entry, local record, and conflict record; never from Firebase.
class UnsyncedRecordRow {
  const UnsyncedRecordRow({
    required this.entityType,
    required this.recordId,
    required this.status,
    required this.operation,
    required this.date,
    this.displayUid,
    this.customerId = '',
    this.vehicleId = '',
    this.lastAttemptAt,
    this.error,
    this.conflictId,
    this.conflictType,
    this.conflictDetail,
  });

  final String entityType;
  final String recordId;

  /// A [QueueStatus] value, or [notQueued] for a record without a queue
  /// entry (counted as unsynced by `WorkspaceCounts.orphanRecords`).
  final String status;
  final String operation;
  final DateTime date;
  final String? displayUid;
  final String customerId;
  final String vehicleId;
  final DateTime? lastAttemptAt;
  final String? error;
  final String? conflictId;
  final String? conflictType;
  final String? conflictDetail;

  static const String notQueued = 'not_queued';

  String get key => '$entityType|$recordId';
}

/// Read-only list of everything that is not yet synced: every queue entry
/// plus records that have no queue entry plus open conflicts. This is the same set
/// `WorkspaceCounts.unsynced` counts, so the table always matches the
/// dashboard badge.
class UnsyncedRecordsReader {
  UnsyncedRecordsReader(this._storage);

  final OfflineStorage _storage;

  Future<List<UnsyncedRecordRow>> load() async {
    final info = await _storage.workspaces.current();
    if (info == null) return const [];

    final rows = <String, UnsyncedRecordRow>{};

    for (final workspaceId in await _storage.workspaces.ownerWorkspaceIds(info)) {
      final entries = await _storage.queue.list(workspaceId);
      final records = await _storage.records.list(workspaceId);
      final openConflicts = await _storage.conflicts.listOpen(workspaceId);

      final recordByKey = {for (final r in records) r.key: r};
      final conflictByKey = {
        for (final c in openConflicts) LocalRecord.keyOf(c.entityType, c.recordId): c
      };

      for (final entry in entries) {
        final record = recordByKey[entry.queueId];
        final conflict = conflictByKey[entry.queueId];
        final row = _fromEntry(entry, record, conflict);
        rows[row.key] = row;
      }

      for (final record in records) {
        if (rows.containsKey(record.key)) continue;
        if (entries.any((e) => e.queueId == record.key)) continue;
        final conflict = conflictByKey[record.key];
        rows[record.key] = _fromOrphan(record, conflict);
      }

      for (final conflict in openConflicts) {
        final key = LocalRecord.keyOf(conflict.entityType, conflict.recordId);
        if (!rows.containsKey(key)) {
          rows[key] = _fromConflictOnly(conflict);
        }
      }
    }

    final list = rows.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Emits the current list, then a fresh one after every queue or conflict change.
  Stream<List<UnsyncedRecordRow>> watch() {
    late StreamController<List<UnsyncedRecordRow>> controller;
    StreamSubscription<void>? subQueue;
    StreamSubscription<void>? subConflicts;
    var loading = false;
    var reloadRequested = false;

    Future<void> emit() async {
      if (loading) {
        reloadRequested = true;
        return;
      }
      loading = true;
      try {
        do {
          reloadRequested = false;
          final rows = await load();
          if (!controller.isClosed) controller.add(rows);
        } while (reloadRequested);
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      } finally {
        loading = false;
      }
    }

    controller = StreamController<List<UnsyncedRecordRow>>(
      onListen: () {
        subQueue = _storage.queue.changes().listen((_) => emit());
        subConflicts = _storage.conflicts.changes().listen((_) => emit());
      },
      onCancel: () async {
        await subQueue?.cancel();
        await subConflicts?.cancel();
      },
    );

    return controller.stream;
  }

  UnsyncedRecordRow _fromEntry(
    SyncQueueEntry entry,
    LocalRecord? record,
    SyncConflict? conflict,
  ) {
    final uId = record?.data['uId']?.toString();
    final category = entry.lastErrorCategory;
    final message = entry.lastError;
    final isConflict = entry.status == QueueStatus.conflict || conflict != null;

    return UnsyncedRecordRow(
      entityType: entry.entityType,
      recordId: entry.recordId,
      status: isConflict ? QueueStatus.conflict : entry.status,
      operation: entry.operation,
      date: record?.updatedAt ?? entry.createdAt,
      displayUid: _displayUid(uId),
      customerId: record?.customerId ?? '',
      vehicleId: record?.vehicleId ?? '',
      lastAttemptAt: entry.lastAttemptAt,
      error: (message == null || message.trim().isEmpty)
          ? (conflict?.detail)
          : (category == null || category.isEmpty
              ? message
              : '$message ($category)'),
      conflictId: conflict?.conflictId,
      conflictType: conflict?.conflictType ?? (isConflict ? 'Data Conflict' : null),
      conflictDetail: conflict?.detail ?? (isConflict ? message : null),
    );
  }

  UnsyncedRecordRow _fromOrphan(LocalRecord record, SyncConflict? conflict) {
    final isConflict = conflict != null;
    return UnsyncedRecordRow(
      entityType: record.entityType,
      recordId: record.recordId,
      status: isConflict ? QueueStatus.conflict : UnsyncedRecordRow.notQueued,
      operation: record.isNew ? SyncOperation.create : SyncOperation.update,
      date: record.updatedAt,
      displayUid: _displayUid(record.data['uId']?.toString()),
      customerId: record.customerId,
      vehicleId: record.vehicleId,
      error: conflict?.detail,
      conflictId: conflict?.conflictId,
      conflictType: conflict?.conflictType,
      conflictDetail: conflict?.detail,
    );
  }

  UnsyncedRecordRow _fromConflictOnly(SyncConflict conflict) {
    return UnsyncedRecordRow(
      entityType: conflict.entityType,
      recordId: conflict.recordId,
      status: QueueStatus.conflict,
      operation: SyncOperation.update,
      date: conflict.detectedAt,
      displayUid: null,
      error: conflict.detail ?? conflict.conflictType,
      conflictId: conflict.conflictId,
      conflictType: conflict.conflictType,
      conflictDetail: conflict.detail,
    );
  }

  /// A provisional uId is shown as such, never as a real one.
  String? _displayUid(String? uId) {
    if (uId == null || uId.trim().isEmpty) return null;
    return PendingUid.isPending(uId) ? '$uId (pending)' : uId;
  }
}
