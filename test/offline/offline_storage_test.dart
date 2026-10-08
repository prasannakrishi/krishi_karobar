import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_karobar/offline/core/workspace_scope.dart';
import 'package:krishi_karobar/offline/offline_constants.dart';
import 'package:krishi_karobar/offline/offline_exceptions.dart';
import 'package:krishi_karobar/offline/offline_models.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:sembast/sembast_memory.dart';

WorkspaceScope scopeFor({
  String user = 'user-1',
  String auth = 'auth-1',
  String vehicle = 'vehicle-1',
}) {
  return WorkspaceScope(
    environment: 'dev',
    ownerUserId: user,
    authUid: auth,
    vehicleId: vehicle,
  );
}

Map<String, Object?> expenseData(String id, {String uId = 'EV01-30001'}) {
  return {
    'id': id,
    'uId': uId,
    'amount': 500,
    'createdAt': '2026-10-01T00:00:00.000Z',
  };
}

Future<OfflineStorage> openStorage() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'offline_test_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return OfflineStorage.forDatabase(db);
}

void main() {
  group('local sequences', () {
    test('allocate increments and never repeats', () async {
      final storage = await openStorage();

      final a = await storage.sequences.allocateNext('expense', 'V01', '2083');
      final b = await storage.sequences.allocateNext('expense', 'V01', '2083');

      expect([a, b], [1, 2]);
    });

    test('continues after the last known server value', () async {
      final storage = await openStorage();

      await storage.sequences
          .recordServerSequence('expense', 'V01', '2083', 25);

      expect(
        await storage.sequences.allocateNext('expense', 'V01', '2083'),
        26,
      );
    });

    test('server value never lowers an issued number', () async {
      final storage = await openStorage();

      await storage.sequences.allocateNext('expense', 'V01', '2083');
      await storage.sequences.allocateNext('expense', 'V01', '2083');
      await storage.sequences.recordServerSequence('expense', 'V01', '2083', 1);

      expect(
        await storage.sequences.allocateNext('expense', 'V01', '2083'),
        3,
      );
    });

    test('scopes are independent', () async {
      final storage = await openStorage();

      await storage.sequences.allocateNext('expense', 'V01', '2083');

      expect(
        await storage.sequences.allocateNext('expense', 'V02', '2083'),
        1,
      );
      expect(
        await storage.sequences.allocateNext('expense', 'V01', '2084'),
        1,
      );
    });
  });

  group('workspace + records + queue', () {
    test('saving a record creates exactly one queue entry', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '+9779812345678');

      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );

      final queue = await storage.queue.list(scope.workspaceId);
      expect(queue.length, 1);
      expect(queue.single.operation, SyncOperation.create);
      expect(queue.single.status, QueueStatus.pending);
    });

    test('editing keeps one queue entry and stays a create', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      for (var amount = 1; amount <= 5; amount++) {
        await storage.localRecords.saveRecord(
          scope,
          entityType: SyncEntity.expense,
          recordId: 'e1',
          data: {...expenseData('e1'), 'amount': amount},
          isNew: true,
        );
      }

      final queue = await storage.queue.list(scope.workspaceId);
      final record = await storage.localRecords.getRecord(
        scope,
        SyncEntity.expense,
        'e1',
      );

      expect(queue.length, 1);
      expect(queue.single.operation, SyncOperation.create);
      expect(record!.revision, 5);
      expect(record.data['amount'], 5);
    });

    test('a record that cannot be encoded saves nothing', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      expect(
        () => storage.localRecords.saveRecord(
          scope,
          entityType: SyncEntity.expense,
          recordId: 'e1',
          data: {'id': 'e1', 'date': DateTime(2026)},
          isNew: true,
        ),
        throwsA(isA<OfflineDataException>()),
      );

      expect(await storage.queue.list(scope.workspaceId), isEmpty);
      expect(await storage.records.count(scope.workspaceId), 0);
    });

    test('the immutable id cannot be changed through saveRecord', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      expect(
        () => storage.localRecords.saveRecord(
          scope,
          entityType: SyncEntity.expense,
          recordId: 'e1',
          data: expenseData('other-id'),
          isNew: true,
        ),
        throwsA(isA<OfflineDataException>()),
      );
    });

    test('another vehicle or user scope is rejected', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );

      expect(
        () => storage.localRecords.getRecord(
          scopeFor(vehicle: 'vehicle-2'),
          SyncEntity.expense,
          'e1',
        ),
        throwsA(isA<OfflineScopeException>()),
      );
      expect(
        () => storage.localRecords.listRecords(scopeFor(user: 'user-2')),
        throwsA(isA<OfflineScopeException>()),
      );
    });

    test('a locked workspace refuses new records', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');
      await storage.workspaces.lock();

      expect(
        () => storage.localRecords.saveRecord(
          scope,
          entityType: SyncEntity.expense,
          recordId: 'e1',
          data: expenseData('e1'),
          isNew: true,
        ),
        throwsA(isA<OfflineScopeException>()),
      );
    });
  });

  group('ownership protection', () {
    test('a different owner cannot open while data is unsynced', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');
      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );

      expect(
        () => storage.workspaces.open(
          scopeFor(user: 'user-2', auth: 'auth-2'),
          ownerPhone: '9800000000',
        ),
        throwsA(isA<WorkspaceOwnershipException>()),
      );

      expect(await storage.workspaces.ownerMatchesPhone('+9779812345678'), true);
      expect(await storage.workspaces.ownerMatchesPhone('9800000000'), false);
    });

    test('the same owner can re-open and recover the workspace', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');
      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );
      await storage.workspaces.lock();

      final reopened = await storage.workspaces.open(
        scope,
        ownerPhone: '9812345678',
      );

      expect(reopened.state, WorkspaceState.active);
      expect(await storage.records.count(scope.workspaceId), 1);
    });

    test('vehicle switch is refused while the old vehicle has data', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');
      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );

      expect(
        () => storage.workspaces.open(
          scopeFor(vehicle: 'vehicle-2'),
          ownerPhone: '9812345678',
        ),
        throwsA(isA<WorkspaceOwnershipException>()),
      );
    });
  });

  group('sync completion and cleanup', () {
    test('verified sync removes local copy and keeps a reference', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      final record = await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );

      final result = await storage.localRecords.completeSync(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        syncedRevision: record.revision,
        verifiedServerData: expenseData('e1'),
        referenceType: ReferenceType.expense,
      );

      expect(result, SyncCompletion.removed);
      expect(await storage.records.count(scope.workspaceId), 0);
      expect(await storage.queue.total(scope.workspaceId), 0);
      expect(
        await storage.snapshots.get(
          scope.workspaceId,
          ReferenceType.expense,
          'e1',
        ),
        isNotNull,
      );
    });

    test('an edit during sync is kept and re-queued as an update', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      final first = await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );

      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: {...expenseData('e1'), 'amount': 900},
        isNew: true,
      );

      final result = await storage.localRecords.completeSync(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        syncedRevision: first.revision,
        verifiedServerData: expenseData('e1'),
        serverUpdatedAt: '2026-10-01T01:00:00.000Z',
        referenceType: ReferenceType.expense,
      );

      final kept = await storage.localRecords.getRecord(
        scope,
        SyncEntity.expense,
        'e1',
      );
      final entry = await storage.queue.get(
        scope.workspaceId,
        SyncEntity.expense,
        'e1',
      );

      expect(result, SyncCompletion.changedDuringSync);
      expect(kept!.data['amount'], 900);
      expect(kept.isNew, false);
      expect(entry!.operation, SyncOperation.update);
      expect(entry.status, QueueStatus.pending);
    });

    test('a conflict keeps the local record and blocks cleanup', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );

      await storage.localRecords.raiseConflict(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        conflictType: ConflictType.idConflict,
        detail: 'id exists with different amount',
      );
      // A second detection must not add a second open conflict.
      await storage.localRecords.raiseConflict(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        conflictType: ConflictType.idConflict,
      );

      expect(await storage.conflicts.countOpen(scope.workspaceId), 1);
      expect(await storage.workspaces.clearIfClean(), false);
      expect(await storage.records.count(scope.workspaceId), 1);
    });

    test('clearIfClean clears only at 0/0/0 and keeps sequences', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      final record = await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );
      await storage.sequences.allocateNext('expense', 'V01', '2083');

      expect(await storage.workspaces.clearIfClean(), false);

      await storage.localRecords.completeSync(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        syncedRevision: record.revision,
        verifiedServerData: expenseData('e1'),
      );

      expect(await storage.workspaces.clearIfClean(), true);
      expect(await storage.workspaces.current(), isNull);
      expect(
        await storage.sequences.allocateNext('expense', 'V01', '2083'),
        2,
      );

      // A different user may now open a workspace.
      final next = await storage.workspaces.open(
        scopeFor(user: 'user-2', auth: 'auth-2'),
        ownerPhone: '9800000000',
      );
      expect(next.ownerUserId, 'user-2');
    });

    test('an orphan local record keeps the workspace dirty', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );
      await storage.queue.remove(scope.workspaceId, SyncEntity.expense, 'e1');

      final counts = await storage.workspaces.currentCounts();

      expect(counts.orphanRecords, 1);
      expect(await storage.workspaces.clearIfClean(), false);
    });

    test('engine uId update does not bump the revision', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );

      final updated = await storage.localRecords.applyEngineUpdate(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        patch: {'uId': 'EV01-30003'},
        uidClaimed: true,
      );
      final entry = await storage.queue.get(
        scope.workspaceId,
        SyncEntity.expense,
        'e1',
      );

      expect(updated.revision, 1);
      expect(updated.data['uId'], 'EV01-30003');
      expect(updated.data['id'], 'e1');
      expect(entry!.uidClaimed, true);

      expect(
        () => storage.localRecords.applyEngineUpdate(
          scope,
          entityType: SyncEntity.expense,
          recordId: 'e1',
          patch: {'id': 'changed'},
        ),
        throwsA(isA<OfflineDataException>()),
      );
    });
  });

  group('queue states', () {
    test('retry later keeps the entry pending with a future time', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );

      await storage.queue.markRetryLater(
        scope.workspaceId,
        SyncEntity.expense,
        'e1',
        category: SyncErrorCategory.network,
        message: 'offline',
        retryAfter: OfflineBackoff.delayFor(1),
      );

      final now = DateTime.now().toUtc();
      final entry = await storage.queue.get(
        scope.workspaceId,
        SyncEntity.expense,
        'e1',
      );

      expect(entry!.attemptCount, 1);
      expect(entry.status, QueueStatus.pending);
      expect(await storage.queue.nextRunnable(scope.workspaceId, now), isEmpty);
      expect(
        await storage.queue.nextRunnable(
          scope.workspaceId,
          now.add(const Duration(minutes: 1)),
        ),
        hasLength(1),
      );
    });

    test('failed entries return to pending on retryFailed', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );
      await storage.queue.markFailed(
        scope.workspaceId,
        SyncEntity.expense,
        'e1',
        category: SyncErrorCategory.permission,
        message: 'denied',
      );

      expect((await storage.workspaces.currentCounts()).failed, 1);

      await storage.queue.retryFailed(scope.workspaceId);

      final counts = await storage.workspaces.currentCounts();
      expect(counts.failed, 0);
      expect(counts.pending, 1);
    });

    test('syncing entries recover to pending after a restart', () async {
      final storage = await openStorage();
      final scope = scopeFor();
      await storage.workspaces.open(scope, ownerPhone: '9812345678');

      await storage.localRecords.saveRecord(
        scope,
        entityType: SyncEntity.expense,
        recordId: 'e1',
        data: expenseData('e1'),
        isNew: true,
      );
      await storage.queue.markSyncing(
        scope.workspaceId,
        SyncEntity.expense,
        'e1',
      );

      expect(await storage.queue.resetSyncingToPending(scope.workspaceId), 1);
    });
  });
}
