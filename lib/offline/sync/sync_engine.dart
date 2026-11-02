import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../services/sequences_service.dart';
import '../core/workspace_scope.dart';
import '../offline_constants.dart';
import '../offline_exceptions.dart';
import '../offline_models.dart';
import '../offline_storage.dart';
import '../uid/expense_uid_service.dart';
import 'record_comparator.dart';
import 'sync_adapter.dart';
import 'sync_adapter_registry.dart';
import 'sync_remote_gateway.dart';

/// Serialized, idempotent background sync for the currently open workspace.
/// UI operations must persist locally first; this engine never runs on the UI
/// call stack and never deletes a local record until Firebase read-back passes.
class SyncEngine {
  SyncEngine({
    required OfflineStorage storage,
    required SyncRemoteGateway remote,
    required SequenceService sequences,
    required ExpenseUidService expenseUid,
    SyncAdapterRegistry? registry,
    this.maxAttempts = 12,
  })  : _storage = storage,
        _remote = remote,
        _sequences = sequences,
        _expenseUid = expenseUid,
        _registry = registry ?? SyncAdapterRegistry.standard();

  final OfflineStorage _storage;
  final SyncRemoteGateway _remote;
  final SequenceService _sequences;
  final ExpenseUidService _expenseUid;
  final SyncAdapterRegistry _registry;
  final int maxAttempts;

  WorkspaceScope? _scope;
  StreamSubscription<bool>? _connectionSubscription;
  Future<void>? _running;
  bool _disposed = false;

  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<int> syncedCount = ValueNotifier<int>(0);
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// Must be called only after WorkspaceRepository.open(scope) succeeds.
  Future<void> start(WorkspaceScope scope) async {
    debugPrint('[SYNC_ENGINE_START_REQUESTED] scope=$scope');
    scope.validate();
    debugPrint('[SYNC_SCOPE_RESOLVED] workspaceId=${scope.workspaceId} authUid=${scope.authUid}');
    if (_disposed) return;
    if (_scope?.workspaceId == scope.workspaceId && _connectionSubscription != null) {
      if (await _remote.isConnected()) unawaited(syncNow());
      return;
    }
    _scope = scope;
    await _connectionSubscription?.cancel();
    _connectionSubscription = _remote.connectionChanges().listen(
      (connected) {
        debugPrint('[SYNC_CONNECTIVITY_CHANGED] connected=$connected');
        if (connected) unawaited(syncNow());
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('Offline sync connection stream: $error');
      },
    );
    if (await _remote.isConnected()) unawaited(syncNow());
  }

  /// Startup recovery: puts entries an INTERRUPTED run left in `syncing` back
  /// to `pending`. While a sync is in flight its `syncing` entries are live,
  /// not stale, so nothing is reset then (repeated workspace activation can
  /// never push in-flight entries back to pending). Runs under the same
  /// single-flight guard as [syncNow], so a sync cannot start halfway
  /// through the reset. Returns how many entries were reset.
  Future<int> recoverInterruptedEntries(String workspaceId) async {
    if (_disposed || _running != null) return 0;

    final recovery = _storage.queue.resetSyncingToPending(workspaceId);
    final run = recovery.then<void>((_) {}, onError: (Object _) {});
    _running = run;
    try {
      return await recovery;
    } finally {
      if (identical(_running, run)) _running = null;
    }
  }

  /// Can be called from connectivity callbacks, app resume, or a manual
  /// refresh. Concurrent calls share the same future (no duplicate writes).
  Future<void> syncNow({bool isManual = false}) {
    if (_disposed || _scope == null) return Future<void>.value();
    if (isManual) {
      debugPrint('[SYNC_MANUAL_TRIGGER] Manual sync requested by user.');
    }
    final active = _running;
    if (active != null) return active;
    final run = _runQueue(isManual: isManual);
    _running = run;
    return run.whenComplete(() {
      if (identical(_running, run)) _running = null;
    });
  }

  Future<void> _runQueue({bool isManual = false}) async {
    final scope = _scope;
    if (scope == null || _disposed) return;

    final connected = await _remote.isConnected();
    debugPrint('[SYNC_ENGINE_STARTED] Workspace=${scope.workspaceId} manual=$isManual');
    debugPrint('[SYNC_CONNECTION_STATE] connected=$connected');

    if (!connected) return;

    isSyncing.value = true;
    syncedCount.value = 0;
    try {
      final counts = await _storage.queue.countsByStatus(scope.workspaceId);
      pendingCount.value = await _runnableCount(scope);
      debugPrint('[SYNC_QUEUE_COUNTS] statusCounts=$counts runnable=${pendingCount.value}');

      if (pendingCount.value == 0 && !isManual) {
        progress.value = 1;
        return;
      }
      progress.value = 0;

      // Repeat passes so child records blocked by a parent in the first pass
      // can sync after that parent has completed. Every pass is finite.
      var madeProgress = true;
      var passes = 0;
      while (madeProgress && passes++ < 4 && !_disposed) {
        madeProgress = false;
        final entries = (await _storage.queue.nextRunnable(
          scope.workspaceId,
          DateTime.now().toUtc(),
          ignoreBackoff: isManual,
        ))
            // Deletion sync arrives with the entity integration stage;
            // until then a tombstone stays queued (and counted).
            .where((e) => e.operation != SyncOperation.delete)
            .toList();

        debugPrint('[SYNC_QUEUE_FETCHED] Fetched ${entries.length} entries for processing.');

        for (final entry in entries) {
          if (_disposed || !await _remote.isConnected()) return;
          debugPrint('[SYNC_QUEUE_ITEM_SELECTED] id=${entry.recordId} entityType=${entry.entityType} op=${entry.operation}');
          final didSync = await _syncEntry(scope, entry);
          if (didSync) {
            madeProgress = true;
            syncedCount.value++;
            debugPrint('[SYNC_QUEUE_COMPLETED] Successfully completed id=${entry.recordId} entityType=${entry.entityType}');
          }
          pendingCount.value = await _runnableCount(scope);
          final total = syncedCount.value + pendingCount.value;
          progress.value = total == 0
              ? 1
              : (syncedCount.value / total).clamp(0.0, 1.0).toDouble();
        }
      }
    } catch (error, stack) {
      debugPrint('Offline SyncEngine queue error: $error\n$stack');
    } finally {
      isSyncing.value = false;
    }
  }

  /// Pending/syncing entries (excluding tombstones) of the workspace.
  Future<int> _runnableCount(WorkspaceScope scope) async {
    final entries = await _storage.queue.list(scope.workspaceId);
    return entries
        .where((e) =>
            e.operation != SyncOperation.delete &&
            (e.status == QueueStatus.pending ||
                e.status == QueueStatus.syncing))
        .length;
  }

  Future<bool> _syncEntry(WorkspaceScope scope, SyncQueueEntry entry) async {
    final type = _canonicalType(entry.entityType);
    final adapter = _registry.tryAdapterFor(type);
    if (adapter == null) {
      await _storage.queue.markFailed(
        scope.workspaceId, entry.entityType, entry.recordId,
        category: SyncErrorCategory.validation,
        message: 'No sync adapter registered for ${entry.entityType}.',
      );
      return false;
    }

    LocalRecord? record = await _storage.localRecords.getRecord(
      scope, entry.entityType, entry.recordId,
    );
    // Existing local records may have been written with the canonical type.
    record ??= await _storage.localRecords.getRecord(scope, type, entry.recordId);
    if (record == null) {
      await _storage.queue.markFailed(
        scope.workspaceId, entry.entityType, entry.recordId,
        category: SyncErrorCategory.validation,
        message: 'Queue points to a missing local record.',
      );
      return false;
    }

    try {
      await _storage.queue.markSyncing(scope.workspaceId, entry.entityType, entry.recordId);
      final context = SyncAdapterContext(
        scope: scope,
        reference: (referenceType, id) async {
          final local = await _storage.snapshots.get(scope.workspaceId, referenceType, id);
          if (local != null) return local;
          final refAdapter = _registry.tryAdapterFor(_canonicalType(referenceType));
          final path = refAdapter?.remotePath ?? _referenceRemotePath(referenceType);
          if (path == null) return null;
          return _remote.readRecord(path, id);
        },
        expenseUid: _expenseUid,
        generateSequence: _sequences.generateSequence,
        generateActivityUid: _sequences.generateActivityUid,
      );

      debugPrint('[SYNC_ADAPTER_STARTED] id=${entry.recordId} entityType=$type adapter=${adapter.runtimeType}');

      // Parent-first dependency check.
      for (final parent in adapter.parentsOf(record)) {
        final parentAdapter = _registry.tryAdapterFor(_canonicalType(parent.entityType));
        if (parentAdapter == null) continue;

        // Check if parent is queued in local sync queue
        final parentQueueEntry = await _storage.queue.get(
          scope.workspaceId,
          parent.entityType,
          parent.recordId,
        );

        if (parentQueueEntry != null && parentQueueEntry.status != QueueStatus.failed) {
          debugPrint('[SYNC_RECORD_SELECTED] ${entry.entityType}/${entry.recordId} waiting for local queued parent ${parent.entityType}/${parent.recordId}');
          await _storage.queue.markRetryLater(
            scope.workspaceId, entry.entityType, entry.recordId,
            category: SyncErrorCategory.recordNotFound,
            message: 'Waiting for local parent ${parent.entityType}/${parent.recordId}.',
            retryAfter: const Duration(seconds: 2),
          );
          return false;
        }

        final localSnapshot = await _storage.snapshots.get(scope.workspaceId, parent.entityType, parent.recordId);
        if (localSnapshot == null) {
          final parentRemote = await _remote.readRecord(parentAdapter.remotePath, parent.recordId);
          if (parentRemote == null) {
            debugPrint('[SYNC_RECORD_SELECTED] Parent ${parent.entityType}/${parent.recordId} not found on remote or snapshot');
            await _storage.queue.markRetryLater(
              scope.workspaceId, entry.entityType, entry.recordId,
              category: SyncErrorCategory.recordNotFound,
              message: 'Waiting for remote parent ${parent.entityType}/${parent.recordId}.',
              retryAfter: const Duration(seconds: 5),
            );
            return false;
          }
        }
      }

      debugPrint('[SYNC_FIREBASE_WRITE_STARTED] id=${entry.recordId} path=${adapter.remotePath}');

      if (entry.operation == SyncOperation.create || record.isNew) {
        final uid = await adapter.resolveUid(context, record, uidClaimed: entry.uidClaimed);
        if (uid != null && uid.changed) {
          record = await _storage.localRecords.applyEngineUpdate(
            scope,
            entityType: record.entityType,
            recordId: record.recordId,
            patch: {'uId': uid.uId},
            uidClaimed: adapter.entityType == SyncEntity.expense,
          );
        }
        final payload = adapter.buildCreatePayload(record);
        if (adapter.writeMode == SyncWriteMode.merge) {
          await _remote.mergeRecord(adapter.remotePath, record.recordId, payload);
          final acknowledged = adapter.verification == SyncVerification.writeAcknowledged;
          final server = acknowledged
              ? payload
              : await _remote.readRecord(adapter.remotePath, record.recordId);
          if (server == null || !RecordComparator.matches(expected: payload, actual: server)) {
            throw StateError('Firebase read-back did not match the saved payload.');
          }
          await _storage.localRecords.completeSync(
            scope,
            entityType: record.entityType,
            recordId: record.recordId,
            syncedRevision: record.revision,
            verifiedServerData: server,
            referenceType: adapter.referenceType,
          );
          debugPrint('[SYNC_FIREBASE_WRITE_SUCCESS] id=${entry.recordId} path=${adapter.remotePath}');
          return true;
        }
        final result = await _remote.createIfAbsent(adapter.remotePath, record.recordId, payload);
        final server = await _remote.readRecord(adapter.remotePath, record.recordId);
        if (server == null) {
          throw TimeoutException('Firebase write was not visible during read-back.');
        }
        if (result == RemoteCreateResult.alreadyExists &&
            !RecordComparator.matches(expected: payload, actual: server)) {
          await _storage.localRecords.raiseConflict(
            scope,
            entityType: record.entityType,
            recordId: record.recordId,
            conflictType: ConflictType.idConflict,
            detail: 'A different server record already uses this immutable id.',
          );
          return false;
        }
        if (!RecordComparator.matches(expected: payload, actual: server)) {
          throw StateError('Firebase read-back did not match the saved payload.');
        }
        await _storage.localRecords.completeSync(
          scope,
          entityType: record.entityType,
          recordId: record.recordId,
          syncedRevision: record.revision,
          verifiedServerData: server,
          serverUpdatedAt: server['updatedAt']?.toString(),
          referenceType: adapter.referenceType,
        );
        debugPrint('[SYNC_FIREBASE_WRITE_SUCCESS] id=${entry.recordId} path=${adapter.remotePath}');
        return true;
      }

      Map<String, Object?>? server;
      if (adapter.verification == SyncVerification.readBack) {
        server = await _remote.readRecord(adapter.remotePath, record.recordId);
        if (server == null) {
          await _storage.localRecords.raiseConflict(
            scope,
            entityType: record.entityType,
            recordId: record.recordId,
            conflictType: ConflictType.dataConflict,
            detail: 'The server record no longer exists.',
          );
          return false;
        }
        final base = record.baseUpdatedAt;
        final remoteUpdatedAt = server['updatedAt']?.toString();
        if (base != null && remoteUpdatedAt != null && base != remoteUpdatedAt) {
          await _storage.localRecords.raiseConflict(
            scope,
            entityType: record.entityType,
            recordId: record.recordId,
            conflictType: ConflictType.dataConflict,
            detail: 'The server record changed after it was loaded.',
          );
          return false;
        }
      }

      final patch = adapter.buildUpdatePatch(record);
      await _remote.mergeRecord(adapter.remotePath, record.recordId, patch);
      final verified = adapter.verification == SyncVerification.writeAcknowledged
          ? {...?server, ...patch}
          : await _remote.readRecord(adapter.remotePath, record.recordId);
      if (verified == null || !RecordComparator.matches(expected: patch, actual: verified)) {
        throw StateError('Firebase update read-back did not match the patch.');
      }
      await _storage.localRecords.completeSync(
        scope,
        entityType: record.entityType,
        recordId: record.recordId,
        syncedRevision: record.revision,
        verifiedServerData: verified,
        serverUpdatedAt: verified['updatedAt']?.toString(),
        referenceType: adapter.referenceType,
      );
      debugPrint('[SYNC_FIREBASE_WRITE_SUCCESS] id=${entry.recordId} path=${adapter.remotePath}');
      return true;
    } on SyncPreparationException catch (error) {
      await _storage.queue.markFailed(
        scope.workspaceId, entry.entityType, entry.recordId,
        category: SyncErrorCategory.validation,
        message: error.message,
      );
    } on OfflineDataException catch (error) {
      await _storage.queue.markFailed(
        scope.workspaceId, entry.entityType, entry.recordId,
        category: SyncErrorCategory.validation,
        message: error.message,
      );
    } on FirebaseException catch (error) {
      debugPrint('[SYNC_FIREBASE_WRITE_FAILED] id=${entry.recordId} entityType=$type error=${error.code} - ${error.message}');
      if (error.code == 'permission-denied' || (error.message?.contains('Permission denied') ?? false)) {
        await _storage.queue.markFailed(
          scope.workspaceId, entry.entityType, entry.recordId,
          category: SyncErrorCategory.permission,
          message: 'Firebase permission denied: ${error.message}',
        );
      } else {
        final attempts = entry.attemptCount + 1;
        if (attempts >= maxAttempts) {
          await _storage.queue.markFailed(
            scope.workspaceId, entry.entityType, entry.recordId,
            category: SyncErrorCategory.unknown,
            message: error.message ?? error.toString(),
          );
        } else {
          await _storage.queue.markRetryLater(
            scope.workspaceId, entry.entityType, entry.recordId,
            category: SyncErrorCategory.network,
            message: error.message ?? error.toString(),
            retryAfter: OfflineBackoff.delayFor(attempts),
          );
        }
      }
    } catch (error, stack) {
      debugPrint('[SYNC_FIREBASE_WRITE_FAILED] id=${entry.recordId} entityType=$type error=$error\n$stack');
      final attempts = entry.attemptCount + 1;
      if (attempts >= maxAttempts) {
        await _storage.queue.markFailed(
          scope.workspaceId, entry.entityType, entry.recordId,
          category: SyncErrorCategory.unknown,
          message: error.toString(),
        );
      } else {
        await _storage.queue.markRetryLater(
          scope.workspaceId, entry.entityType, entry.recordId,
          category: SyncErrorCategory.network,
          message: error.toString(),
          retryAfter: OfflineBackoff.delayFor(attempts),
        );
      }
    }
    return false;
  }

  String? _referenceRemotePath(String type) {
    switch (type) {
      case 'vehicle':
        return 'vehicles';
      case 'service':
        return 'services';
      case 'expense_category':
      case 'expenseCategory':
        return 'expensecategories';
      case 'activity_location':
      case 'activity_locations':
        return 'activity_locations';
      case 'expense_location':
      case 'expense_locations':
        return 'expense_locations';
      default:
        return null;
    }
  }

  String _canonicalType(String type) => SyncEntity.canonical(type);

  Future<void> dispose() async {
    _disposed = true;
    await _connectionSubscription?.cancel();
    isSyncing.dispose();
    syncedCount.dispose();
    pendingCount.dispose();
    progress.dispose();
  }
}
