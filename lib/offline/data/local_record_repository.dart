import 'package:sembast/sembast.dart';

import '../core/record_index.dart';
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
/// open workspace (environment, owner, auth identity). A record and its
/// queue entry are always written in ONE transaction, so a pending record
/// can never exist without a sync reference.
///
/// There is one workspace per environment and owner. A record's vehicle is
/// its own `vehicleId` field (indexed), and the owner's access policy
/// (`WorkspaceAccess`: roles per entity, assigned vehicles) decides whether
/// it may be written or read.
class LocalRecordRepository {
  LocalRecordRepository({
    required Database database,
    required WorkspaceRepository workspaces,
    required LocalRecordDao records,
    required SyncQueueDao queue,
    required SyncConflictDao conflicts,
    required ReferenceSnapshotDao snapshots,
    this.onQueued,
  })  : _db = database,
        _workspaces = workspaces,
        _records = records,
        _queue = queue,
        _conflicts = conflicts,
        _snapshots = snapshots;

  /// Fields that decide how much a payment or activity is paid or due. A
  /// patch touching them must say when it was computed (`updatedAt`) so an
  /// older calculation can never overwrite a newer one.
  static const Set<String> staleGuardedFields = {
    'paidAmount',
    'dueAmount',
    'discountAmount',
    'status',
    'paidAt',
    'receivedBy',
  };

  static const Set<String> _staleGuardedEntities = {
    SyncEntity.activity,
    SyncEntity.payment,
  };

  final Database _db;
  final WorkspaceRepository _workspaces;
  final LocalRecordDao _records;
  final SyncQueueDao _queue;
  final SyncConflictDao _conflicts;
  final ReferenceSnapshotDao _snapshots;
  final void Function()? onQueued;

  LocalRecordDao get dao => _records;

  /// Saves a full record created or edited offline and queues it
  /// atomically.
  ///
  /// * New record: [isNew] true -> queued as `create`.
  /// * Server record edited offline: [isNew] false and [baseUpdatedAt] =
  ///   the server `updatedAt` it was loaded with -> queued as `update`.
  /// * Saving an existing local record MERGES [data] into it (keys not in
  ///   [data], such as engine-set fields, are kept) and keeps one queue
  ///   entry; a create stays a create.
  /// * A tombstoned (locally deleted) record is never edited or revived.
  /// * A save whose `updatedAt` is older than the stored one is refused
  ///   ([OfflineDataException.stale]).
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

    final type = SyncEntity.canonical(entityType);
    final cleaned = _validatedData(data, recordId);

    final saved = await _db.transaction((txn) async {
      await _requireWorkspace(txn, scope, writeType: type);
      await _requireKeyFree(txn, scope, type, recordId);

      final existing = await _records.get(
        scope.workspaceId,
        type,
        recordId,
        client: txn,
      );

      if (existing != null && existing.isDeleted) {
        throw OfflineDataException.tombstoned(details: '$type/$recordId');
      }
      if (existing != null) {
        _assertNotStale(existing.data, cleaned, '$type/$recordId');
      }

      final record = await _store(
        txn,
        scope,
        type: type,
        recordId: recordId,
        existing: existing,
        data: existing == null ? cleaned : {...existing.data, ...cleaned},
        isNew: isNew,
        baseUpdatedAt: baseUpdatedAt,
      );

      return record;
    });
    // The UI waits only for the local transaction. Sync runs asynchronously.
    onQueued?.call();
    return saved;
  }

  /// Changes some fields of a record without replacing the rest.
  ///
  /// * The record exists locally: [patch] is merged into it (a pending
  ///   create stays a create).
  /// * Not local yet: the verified server copy kept in the reference
  ///   snapshot is the base, and the record is queued as an `update` whose
  ///   `baseUpdatedAt` is that copy's `updatedAt`, so the engine can detect
  ///   that the server changed meanwhile. With no base there is nothing to
  ///   patch, and a blind partial write is refused.
  /// * [staleGuardedFields] (paid/due/discount/status...) on an activity or
  ///   payment need an `updatedAt` in [patch], and it must not be older than
  ///   the base's `updatedAt`.
  Future<LocalRecord> patchRecord(
    WorkspaceScope scope, {
    required String entityType,
    required String recordId,
    required Map<String, Object?> patch,
  }) async {
    _requireText(entityType, 'entityType');
    _requireText(recordId, 'recordId');

    if (patch.containsKey('id')) {
      throw const OfflineDataException.invalid(
        message: 'The immutable record id cannot be changed.',
      );
    }

    final type = SyncEntity.canonical(entityType);
    final cleaned = _validatedData(patch, null);

    final saved = await _db.transaction((txn) async {
      await _requireWorkspace(txn, scope, writeType: type);
      await _requireKeyFree(txn, scope, type, recordId);

      final existing = await _records.get(
        scope.workspaceId,
        type,
        recordId,
        client: txn,
      );

      if (existing != null && existing.isDeleted) {
        throw OfflineDataException.tombstoned(details: '$type/$recordId');
      }

      Map<String, Object?> base;
      String? baseUpdatedAt;
      if (existing != null) {
        base = existing.data;
      } else {
        final snapshot = await _snapshots.get(
          scope.workspaceId,
          type,
          recordId,
          client: txn,
        );
        if (snapshot == null) {
          throw OfflineDataException.missingRecord(
            details: '$type/$recordId has no local or server base to patch',
          );
        }
        base = snapshot;
        baseUpdatedAt = snapshot['updatedAt']?.toString();
      }

      if (_staleGuardedEntities.contains(type) &&
          cleaned.keys.any(staleGuardedFields.contains)) {
        if (_time(cleaned['updatedAt']) == null) {
          throw OfflineDataException.invalid(
            message: 'A payment or balance change must carry its updatedAt.',
            details: '$type/$recordId',
          );
        }
      }
      _assertNotStale(base, cleaned, '$type/$recordId');

      return _store(
        txn,
        scope,
        type: type,
        recordId: recordId,
        existing: existing,
        data: {...base, ...cleaned, 'id': recordId},
        isNew: false,
        baseUpdatedAt: baseUpdatedAt,
      );
    });

    onQueued?.call();
    return saved;
  }

  /// Marks a local record deleted (tombstone) and queues a `delete`. The
  /// original record and its data are kept: a deletion is never allowed to
  /// destroy unsynchronized data, and a remote refresh can consult
  /// [tombstones] so it does not bring the record back. Deleting an
  /// already-tombstoned record is a no-op.
  Future<LocalRecord> markDeleted(
    WorkspaceScope scope, {
    required String entityType,
    required String recordId,
  }) async {
    _requireText(entityType, 'entityType');
    _requireText(recordId, 'recordId');

    final type = SyncEntity.canonical(entityType);

    final deleted = await _db.transaction((txn) async {
      await _requireWorkspace(txn, scope, writeType: type);

      final existing = await _records.get(
        scope.workspaceId,
        type,
        recordId,
        client: txn,
      );

      if (existing == null) {
        throw OfflineDataException.missingRecord(details: '$type/$recordId');
      }
      if (existing.isDeleted) return existing;

      final now = DateTime.now().toUtc();
      final tombstone = existing.copyWith(
        deletedAt: now,
        revision: existing.revision + 1,
        updatedAt: now,
      );

      await _records.put(tombstone, client: txn);
      await _queue.upsertForDelete(
        workspaceId: scope.workspaceId,
        entityType: type,
        recordId: recordId,
        client: txn,
      );

      return tombstone;
    });

    onQueued?.call();
    return deleted;
  }

  /// One record, or `null`. A record of a vehicle the owner may not use is
  /// refused rather than returned.
  Future<LocalRecord?> getRecord(
    WorkspaceScope scope,
    String entityType,
    String recordId,
  ) async {
    final type = SyncEntity.canonical(entityType);
    final info = await _requireWorkspace(_db, scope);
    final record = await _records.get(scope.workspaceId, type, recordId);

    if (record != null) _requireReadable(info, record);
    return record;
  }

  /// Records of the workspace. Filters use the flat index fields
  /// (`entityType`, `vehicleId`, `customerId`, `recordStatus`,
  /// `isDeleted`). Records of vehicles the owner may not use are left out.
  Future<List<LocalRecord>> listRecords(
    WorkspaceScope scope, {
    String? entityType,
    String? vehicleId,
    String? customerId,
    String? status,
    bool includeDeleted = true,
  }) async {
    final info = await _requireWorkspace(_db, scope);

    final records = await _records.list(
      scope.workspaceId,
      entityType: entityType,
      vehicleId: vehicleId,
      customerId: customerId,
      status: status,
      includeDeleted: includeDeleted,
    );

    final access = info.access;
    if (access == null) return records;
    return records
        .where((record) => access.canUseVehicle(record.vehicleId))
        .toList();
  }

  /// Locally deleted records whose deletion is not synchronized yet. A
  /// remote refresh must not restore them.
  Future<List<LocalRecord>> tombstones(
    WorkspaceScope scope, {
    String? entityType,
  }) async {
    await _requireWorkspace(_db, scope);

    final all = await _records.listTombstones(scope.workspaceId);
    if (entityType == null) return all;

    final type = SyncEntity.canonical(entityType);
    return all.where((record) => record.entityType == type).toList();
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

    final type = SyncEntity.canonical(entityType);
    final cleaned = _validatedData(patch, null);

    return _db.transaction((txn) async {
      await _requireWorkspace(txn, scope);

      final record = await _records.get(
        scope.workspaceId,
        type,
        recordId,
        client: txn,
      );

      if (record == null) {
        throw OfflineDataException.missingRecord(details: '$type/$recordId');
      }

      final updated = record.copyWith(
        data: {...record.data, ...cleaned},
        updatedAt: DateTime.now().toUtc(),
      );

      await _records.put(updated, client: txn);

      if (uidClaimed) {
        await _queue.markUidClaimed(
          scope.workspaceId,
          type,
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
  /// * Tombstoned record: nothing is removed; the deletion is still
  ///   pending ([SyncCompletion.keptTombstone]).
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
    final type = SyncEntity.canonical(entityType);

    return _db.transaction((txn) async {
      await _requireWorkspace(txn, scope);

      final record = await _records.get(
        scope.workspaceId,
        type,
        recordId,
        client: txn,
      );

      if (record != null && record.isDeleted) {
        await _records.put(
          record.copyWith(isNew: false, baseUpdatedAt: serverUpdatedAt),
          client: txn,
        );

        await _queue.resetToPending(
          scope.workspaceId,
          type,
          recordId,
          operation: SyncOperation.delete,
          resetAttempts: true,
          client: txn,
        );

        return SyncCompletion.keptTombstone;
      }

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
          type,
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
        type,
        recordId,
        client: txn,
      );
      await _queue.remove(
        scope.workspaceId,
        type,
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
    final type = SyncEntity.canonical(entityType);

    return _db.transaction((txn) async {
      await _requireWorkspace(txn, scope);

      final record = await _records.get(
        scope.workspaceId,
        type,
        recordId,
        client: txn,
      );

      if (record == null) {
        throw OfflineDataException.missingRecord(details: '$type/$recordId');
      }

      final conflict = await _conflicts.open(
        workspaceId: scope.workspaceId,
        entityType: type,
        recordId: recordId,
        conflictType: conflictType,
        detail: detail,
        client: txn,
      );

      await _queue.markConflict(
        scope.workspaceId,
        type,
        recordId,
        message: detail ?? conflictType,
        client: txn,
      );

      return conflict;
    });
  }

  /// Builds the stored record (index fields, owner type) and writes it with
  /// its queue entry. Runs inside the caller's transaction.
  Future<LocalRecord> _store(
    DatabaseClient txn,
    WorkspaceScope scope, {
    required String type,
    required String recordId,
    required LocalRecord? existing,
    required Map<String, Object?> data,
    required bool isNew,
    required String? baseUpdatedAt,
  }) async {
    final info = (await _workspaces.current(client: txn))!;
    final index = LocalRecordIndex.derive(
      entityType: type,
      recordId: recordId,
      data: data,
    );

    final access = info.access;
    if (access != null && !access.canUseVehicle(index.vehicleId)) {
      throw OfflineScopeException.notAllowed(
        details: 'vehicle ${index.vehicleId}',
      );
    }

    final now = DateTime.now().toUtc();
    final ownerType = access?.userType ?? '';

    final record = existing == null
        ? LocalRecord(
            workspaceId: scope.workspaceId,
            entityType: type,
            recordId: recordId,
            data: data,
            isNew: isNew,
            revision: 1,
            baseUpdatedAt: isNew ? null : baseUpdatedAt,
            createdAt: now,
            updatedAt: now,
            vehicleId: index.vehicleId,
            customerId: index.customerId,
            recordStatus: index.status,
            ownerType: ownerType,
          )
        : existing.copyWith(
            data: data,
            revision: existing.revision + 1,
            updatedAt: now,
            vehicleId: index.vehicleId,
            customerId: index.customerId,
            recordStatus: index.status,
            ownerType: ownerType,
          );

    await _records.put(record, client: txn);

    await _queue.upsertForSave(
      workspaceId: scope.workspaceId,
      entityType: type,
      recordId: recordId,
      isNew: record.isNew,
      client: txn,
    );

    return record;
  }

  /// Validates [scope] against the open workspace and returns it.
  ///
  /// * the scope itself must be well formed (no blank part);
  /// * environment, owner and auth identity must equal the open workspace's;
  /// * with [writeType] (a write): the workspace must be unlocked and the
  ///   owner's access policy must allow writing that entity. A workspace
  ///   without an access profile cannot be written to until the owner opens
  ///   it again with one.
  Future<WorkspaceInfo> _requireWorkspace(
    DatabaseClient client,
    WorkspaceScope scope, {
    String? writeType,
  }) async {
    scope.validate();

    final info = await _workspaces.current(client: client);

    if (info == null) throw const OfflineScopeException.noWorkspace();

    if (info.environment != scope.environment ||
        info.ownerUserId != scope.ownerUserId ||
        info.authUid != scope.authUid) {
      throw OfflineScopeException.mismatch(
        details:
            'open=${info.workspaceId} (authUid=${info.authUid}) requested=${scope.workspaceId} (authUid=${scope.authUid})',
      );
    }

    if (writeType != null) {
      if (info.isLocked) throw const OfflineScopeException.locked();

      final access = info.access;
      if (access == null) {
        throw const OfflineScopeException.notAllowed(
          details: 'the workspace has no access profile',
        );
      }
      if (!access.canWrite(writeType)) {
        throw OfflineScopeException.notAllowed(
          details: '${access.userType} may not write $writeType',
        );
      }
    }

    return info;
  }

  void _requireReadable(WorkspaceInfo info, LocalRecord record) {
    final access = info.access;
    if (access != null && !access.canUseVehicle(record.vehicleId)) {
      throw OfflineScopeException.notAllowed(
        details: 'vehicle ${record.vehicleId}',
      );
    }
  }

  /// A record key is `entityType|recordId` for the whole database. Refuse
  /// to write over a record that belongs to a different workspace.
  Future<void> _requireKeyFree(
    DatabaseClient client,
    WorkspaceScope scope,
    String type,
    String recordId,
  ) async {
    final holder = await _records.workspaceOf(type, recordId, client: client);

    if (holder != null && holder != scope.workspaceId) {
      throw OfflineScopeException.mismatch(
        details: '$type/$recordId belongs to $holder',
      );
    }
  }

  static DateTime? _time(Object? value) {
    return value is String ? DateTime.tryParse(value)?.toUtc() : null;
  }

  /// Refuses a change computed before the value it would overwrite: when
  /// both carry an `updatedAt` and the incoming one is older.
  void _assertNotStale(
    Map<String, Object?> current,
    Map<String, Object?> incoming,
    String what,
  ) {
    final incomingAt = _time(incoming['updatedAt']);
    final currentAt = _time(current['updatedAt']);

    if (incomingAt != null &&
        currentAt != null &&
        incomingAt.isBefore(currentAt)) {
      throw OfflineDataException.stale(
        details: '$what incoming=$incomingAt current=$currentAt',
      );
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
