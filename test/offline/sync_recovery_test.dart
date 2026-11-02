import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_karobar/models/user_types.dart';
import 'package:krishi_karobar/offline/core/workspace_access.dart';
import 'package:krishi_karobar/offline/core/workspace_scope.dart';
import 'package:krishi_karobar/offline/offline_constants.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:krishi_karobar/offline/sync/sync_engine.dart';
import 'package:krishi_karobar/offline/sync/sync_remote_gateway.dart';
import 'package:krishi_karobar/offline/uid/expense_uid_service.dart';
import 'package:krishi_karobar/services/sequences_service.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

class _FakeGateway extends Fake implements SyncRemoteGateway {
  bool connected = false;

  /// While set, the connection check stays pending: a sync is "in flight".
  Completer<bool>? hold;

  @override
  Stream<bool> connectionChanges() => const Stream<bool>.empty();

  @override
  Future<bool> isConnected() => hold?.future ?? Future<bool>.value(connected);
}

class _FakeSequences extends Fake implements SequenceService {}

class _FakeExpenseUid extends Fake implements ExpenseUidService {}

void main() {
  late Database db;
  late OfflineStorage storage;
  late WorkspaceScope scope;
  late _FakeGateway gateway;
  late SyncEngine engine;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('recovery.db');
    storage = OfflineStorage.forDatabase(db);
    scope = const WorkspaceScope(
      environment: 'dev',
      ownerUserId: 'user-1',
      authUid: 'auth-1',
    );
    await storage.workspaces.open(
      scope,
      ownerPhone: '9800000000',
      access: const WorkspaceAccess(
        userType: UserTypes.organization,
        roles: ['admin'],
        allVehicles: true,
      ),
    );

    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.customer,
      recordId: 'c1',
      data: {'id': 'c1', 'name': 'Ram', 'updatedAt': '2026-10-31T00:00:00.000Z'},
      isNew: true,
    );
    await storage.queue.markSyncing(scope.workspaceId, SyncEntity.customer, 'c1');

    gateway = _FakeGateway();
    engine = SyncEngine(
      storage: storage,
      remote: gateway,
      sequences: _FakeSequences(),
      expenseUid: _FakeExpenseUid(),
    );
    await engine.start(scope);
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<String?> status() async =>
      (await storage.queue.get(scope.workspaceId, SyncEntity.customer, 'c1'))
          ?.status;

  test('repeated activation does not reset entries of a sync that is in flight',
      () async {
    gateway.hold = Completer<bool>();
    final running = engine.syncNow(); // in flight, waiting on the connection

    expect(await engine.recoverInterruptedEntries(scope.workspaceId), 0);
    expect(await engine.recoverInterruptedEntries(scope.workspaceId), 0);
    expect(await status(), QueueStatus.syncing);

    gateway.hold!.complete(false);
    await running;
  });

  test('an entry left syncing by an interrupted run is reset once nothing is in flight',
      () async {
    expect(await status(), QueueStatus.syncing);

    expect(await engine.recoverInterruptedEntries(scope.workspaceId), 1);
    expect(await status(), QueueStatus.pending);

    // Nothing left to reset on a repeated activation.
    expect(await engine.recoverInterruptedEntries(scope.workspaceId), 0);
  });
}
