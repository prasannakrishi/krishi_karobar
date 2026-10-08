import 'package:sembast/sembast.dart';

import '../core/workspace_scope.dart';
import '../offline_constants.dart';
import '../offline_exceptions.dart';
import '../offline_models.dart';
import 'local_record_dao.dart';
import 'reference_snapshot_dao.dart';
import 'sync_conflict_dao.dart';
import 'sync_queue_dao.dart';
import 'workspace_repository.dart';

/// Scoped access to pending business records.
///
/// Every public method needs a [WorkspaceScope] and verifies it against the
/// open workspace (owner, auth identity, vehicle). A record and its queue
/// entry are always written in ONE transaction, so a pending record can
/// never exist without a sync reference.
class LocalRecordRepository {
  LocalRecordRepository({
    required Database database,
    required WorkspaceRepository workspaces,
    required LocalRecordDao records,
    required SyncQueueDao queue,
    required SyncConflictDao conflicts,
    required ReferenceSnapshotDao snapshots,
  })  : _db = database,
        _workspaces = workspaces,
        _records = records,
        _queue = queue,
        _conflicts = conflicts,
        _snapshots = snapshots;

  final Database _db;
  final WorkspaceRepository _workspaces;
  final LocalRecordDao _records;
  final SyncQueueDao _queue;
  final SyncConflictDao _conflicts;
  final ReferenceSnapshotDao _snapshots;

  /// Saves a record created or edited offline and queues it atomically.
  ///
  /// * New record: [isNew] true -> queued as `create`.
  /// * Server record edited offline: [isNew] false and [baseUpdatedAt] =
  ///   the server `updatedAt` it was loaded with -> queued as `update`.
  /// * Saving again keeps one entry; a create stays a create.
  ///
  /// The immutable `id` is checked: [data]`['id']`, when present, must
  /// equal [recordId]. `uId` rewrites after sync go through
  /// [applyEngineUpdate], not here.
  Future<LocalRecord> saveRecord(
    WorkspaceScope scope, {
    required String entityType,
    required String recordId,
    required Map<String, Object?> data,
    required bool isNew,
    String? baseUpdatedAt,
  }) async {
    _requireText(entityType, 'entityType');
    _requireText(recordId, 'recordId');

    final cleaned = _validatedData(data, recordId);

    return _db.transaction((txn) async {
      await _requireWorkspace(txn, scope, requireActive: true);

      final now = DateTime.now().toUtc();
      final existing = await _records.get(
        scope.workspaceId,
        entityType,
        recordId,
        client: txn,
      );

      final record = existing == null
          ? LocalRecord(
              workspaceId: scope.workspaceId,
              entityType: entityType,
              recordId: recordId,
              data: cleaned,
              isNew: isNew,
              revision: 1,
              baseUpdatedAt: isNew ? null : baseUpdatedAt,
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(
              data: cleaned,
              revision: existing.revision + 1,
              updatedAt: now,
            );

      await _records.put(record, client: txn);

      await _queue.upsertForSave(
        workspaceId: scope.workspaceId,
        entityType: entityType,
        recordId: recordId,
        isNew: record.isNew,
        client: txn,
      );

      return record;
    });
  }

  Future<LocalRecord?> getRecord(
    WorkspaceScope scope,
    String entityType,
    String recordId,
  ) async {
    await _requireWorkspace(_db, scope);
    return _records.get(scope.workspaceId, entityType, recordId);
  }

  Future<List<LocalRecord>> listRecords(
    WorkspaceScope scope, {
    String? entityType,
  }) async {
    await _requireWorkspace(_db, scope);
    return _records.list(scope.workspaceId, entityType: entityType);
  }

  /// Engine-side change to a record's data that is NOT a user edit (for
  /// example the new `uId` after a sequence conflict). The revision is left
  /// alone so it is not mistaken for an edit made during sync. The
  /// immutable `id` cannot be patched.
  Future<LocalRecord> applyEngineUpdate(
    WorkspaceScope scope, {
    required String entityType,
    required String recordId,
    required Map<String, Object?> patch,
    bool uidClaimed = false,
  }) {
    if (patch.containsKey('id')) {
      throw const OfflineDataException.invalid(
        message: 'The immutable record id cannot be changed.',
      );
    }

    final cleaned = _validatedData(patch, null);

    return _db.transaction((txn) async {
      await _requireWorkspace(txn, scope);

      final record = await _records.get(
        scope.workspaceId,
        entityType,
        recordId,
        client: txn,
      );

      if (record == null) {
        throw OfflineDataException.missingRecord(
          details: '$entityType/$recordId',
        );
      }

      final updated = record.copyWith(
        data: {...record.data, ...cleaned},
        updatedAt: DateTime.now().toUtc(),
      );

      await _records.put(updated, client: txn);

      if (uidClaimed) {
        await _queue.markUidClaimed(
          scope.workspaceId,
          entityType,
          recordId,
          client: txn,
        );
      }

      return updated;
    });
  }

  /// Finishes a record's sync. Call ONLY after the engine has written the
  /// record, read it back from Firebase and confirmed the expected data
  /// ([verifiedServerData] is that confirmed server copy).
  ///
  /// * Unchanged since the engine read it ([syncedRevision] matches): the
  ///   local copy and queue entry are removed and the server copy moves to
  ///   the read-only reference snapshot (when [referenceType] is given), so
  ///   the offline view keeps showing it.
  /// * Edited during the sync: nothing is discarded; the record becomes an
  ///   `update` on top of the now-existing server record.
  Future<SyncCompletion> completeSync(
    WorkspaceScope scope, {
    required String entityType,
    required String recordId,
    required int syncedRevision,
    required Map<String, Object?> verifiedServerData,
    String? serverUpdatedAt,
    String? referenceType,
  }) {
    return _db.transaction((txn) async {
      await _requireWorkspace(txn, scope);

      final record = await _records.get(
        scope.workspaceId,
        entityType,
        recordId,
        client: txn,
      );

      if (record != null && record.revision != syncedRevision) {
        await _records.put(
          record.copyWith(
            isNew: false,
            baseUpdatedAt: serverUpdatedAt,
          ),
          client: txn,
        );

        await _queue.resetToPending(
          scope.workspaceId,
          entityType,
          recordId,
          operation: SyncOperation.update,
          resetAttempts: true,
          client: txn,
        );

        return SyncCompletion.changedDuringSync;
      }

      if (referenceType != null) {
        await _snapshots.put(
          workspaceId: scope.workspaceId,
          type: referenceType,
          recordId: recordId,
          data: verifiedServerData,
          client: txn,
        );
      }

      await _records.delete(
        scope.workspaceId,
        entityType,
        recordId,
        client: txn,
      );
      await _queue.remove(
        scope.workspaceId,
        entityType,
        recordId,
        client: txn,
      );

      return SyncCompletion.removed;
    });
  }

  /// Records a conflict and stops the queue entry. The local record is
  /// kept untouched (never deleted, never overwritten).
  Future<SyncConflict> raiseConflict(
    WorkspaceScope scope, {
    required String entityType,
    required String recordId,
    required String conflictType,
    String? detail,
  }) {
    return _db.transaction((txn) async {
      await _requireWorkspace(txn, scope);

      final record = await _records.get(
        scope.workspaceId,
        entityType,
        recordId,
        client: txn,
      );

      if (record == null) {
        throw OfflineDataException.missingRecord(
          details: '$entityType/$recordId',
        );
      }

      final conflict = await _conflicts.open(
        workspaceId: scope.workspaceId,
        entityType: entityType,
        recordId: recordId,
        conflictType: conflictType,
        detail: detail,
        client: txn,
      );

      await _queue.markConflict(
        scope.workspaceId,
        entityType,
        recordId,
        message: detail ?? conflictType,
        client: txn,
      );

      return conflict;
    });
  }

  Future<void> _requireWorkspace(
    DatabaseClient client,
    WorkspaceScope scope, {
    bool requireActive = false,
  }) async {
    scope.validate();

    final info = await _workspaces.current(client: client);

    if (info == null) throw const OfflineScopeException.noWorkspace();

    if (info.workspaceId != scope.workspaceId ||
        info.authUid != scope.authUid) {
      throw OfflineScopeException.mismatch(
        details: 'open=${info.workspaceId} requested=${scope.workspaceId}',
      );
    }

    if (requireActive && info.isLocked) {
      throw const OfflineScopeException.locked();
    }
  }

  void _requireText(String value, String name) {
    if (value.trim().isEmpty) {
      throw OfflineDataException.invalid(message: '$name must not be empty.');
    }
  }

  /// Copies [data] and rejects anything Sembast cannot store faithfully
  /// (for example a raw `DateTime`): failing loudly beats silently
  /// corrupting a financial record. Models already emit ISO strings.
  Map<String, Object?> _validatedData(
    Map<String, Object?> data,
    String? recordId,
  ) {
    if (data.isEmpty) {
      throw const OfflineDataException.invalid(
        message: 'An empty record cannot be saved.',
      );
    }

    final id = data['id'];
    if (recordId != null && id != null && id.toString() != recordId) {
      throw OfflineDataException.invalid(
        message: 'The immutable record id cannot be changed.',
        details: 'recordId=$recordId data.id=$id',
      );
    }

    _assertEncodable(data, 'data');
    return deepCopyMap(data);
  }

  void _assertEncodable(Object? value, String path) {
    if (value == null || value is bool || value is num || value is String) {
      return;
    }

    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        _assertEncodable(value[i], '$path[$i]');
      }
      return;
    }

    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw OfflineDataException.invalid(
            details: '$path has a non-string key "${entry.key}"',
          );
        }
        _assertEncodable(entry.value, '$path.${entry.key}');
      }
      return;
    }

    throw OfflineDataException.invalid(
      details: '$path has unsupported type ${value.runtimeType}',
    );
  }
}
