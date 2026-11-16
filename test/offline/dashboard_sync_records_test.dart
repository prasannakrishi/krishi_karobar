import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_karobar/features/home/controller/sync_records_controller.dart';
import 'package:krishi_karobar/models/user_types.dart';
import 'package:krishi_karobar/offline/core/workspace_access.dart';
import 'package:krishi_karobar/offline/core/workspace_scope.dart';
import 'package:krishi_karobar/offline/offline_constants.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:krishi_karobar/offline/sync/unsynced_records_reader.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late Database db;
  late OfflineStorage storage;
  late WorkspaceScope scope;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('dashboard_sync.db');
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
  });

  tearDown(() async {
    await db.close();
  });

  test('Pending, Failed, and Conflict record classification & tab counts', () async {
    // 1. Create a Pending record
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.customer,
      recordId: 'c1',
      data: {'id': 'c1', 'name': 'Pending Cust'},
      isNew: true,
    );

    // 2. Create a Failed record
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.activity,
      recordId: 'a1',
      data: {'id': 'a1', 'uId': 'A-1'},
      isNew: true,
    );
    await storage.queue.markFailed(
      scope.workspaceId,
      SyncEntity.activity,
      'a1',
      category: SyncErrorCategory.permission,
      message: 'Permission denied for activity',
    );

    // 3. Create a Conflict record
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.expense,
      recordId: 'e1',
      data: {'id': 'e1', 'uId': 'E-1'},
      isNew: true,
    );
    await storage.localRecords.raiseConflict(
      scope,
      entityType: SyncEntity.expense,
      recordId: 'e1',
      conflictType: 'dataConflict',
      detail: 'Server data changed',
    );

    final reader = UnsyncedRecordsReader(storage);
    final rows = await reader.load();

    final controller = SyncRecordsController(
      source: Stream.value(rows),
    );
    controller.onInit();
    await Future<void>.delayed(Duration.zero);

    expect(controller.pendingCount, 1);
    expect(controller.pendingRows.single.recordId, 'c1');

    expect(controller.failedCount, 1);
    expect(controller.failedRows.single.recordId, 'a1');
    expect(controller.failedRows.single.error, 'Permission denied for activity (permission)');

    expect(controller.conflictCount, 1);
    expect(controller.conflictRows.single.recordId, 'e1');
    expect(controller.conflictRows.single.error, 'Server data changed (data_conflict)');

    controller.onClose();
  });

  test('Successful sync removes records from Pending/Failed immediately', () async {
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.customer,
      recordId: 'c1',
      data: {'id': 'c1', 'name': 'Pending Cust'},
      isNew: true,
    );

    final reader = UnsyncedRecordsReader(storage);
    expect((await reader.load()).length, 1);

    // Complete sync
    await storage.localRecords.completeSync(
      scope,
      entityType: SyncEntity.customer,
      recordId: 'c1',
      syncedRevision: 1,
      verifiedServerData: {'id': 'c1', 'name': 'Pending Cust'},
    );

    final rowsAfter = await reader.load();
    expect(rowsAfter, isEmpty);
  });

  test('Conflict resolution removes records from Conflict', () async {
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.expense,
      recordId: 'e1',
      data: {'id': 'e1'},
      isNew: true,
    );
    final conflict = await storage.localRecords.raiseConflict(
      scope,
      entityType: SyncEntity.expense,
      recordId: 'e1',
      conflictType: 'dataConflict',
      detail: 'Server mismatch',
    );

    final reader = UnsyncedRecordsReader(storage);
    var rows = await reader.load();
    expect(rows.single.status, QueueStatus.conflict);

    // Resolve conflict
    await storage.localRecords.resolveConflict(
      scope,
      conflictId: conflict.conflictId,
      resolution: 'keep_local',
    );

    rows = await reader.load();
    expect(rows.single.status, QueueStatus.pending);
    expect(rows.single.conflictId, isNull);
  });

  test('App restart state persistence restores exact queue and conflict states', () async {
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.customer,
      recordId: 'c1',
      data: {'id': 'c1'},
      isNew: true,
    );
    await storage.queue.markFailed(
      scope.workspaceId,
      SyncEntity.customer,
      'c1',
      category: SyncErrorCategory.network,
      message: 'Network timeout',
    );

    // Re-open storage on same database
    final storage2 = OfflineStorage.forDatabase(db);
    final reader2 = UnsyncedRecordsReader(storage2);
    final rows = await reader2.load();

    expect(rows.length, 1);
    expect(rows.single.recordId, 'c1');
    expect(rows.single.status, QueueStatus.failed);
    expect(rows.single.error, 'Network timeout (network)');
  });

  test('Business records are preserved in local database when present in sync reader', () async {
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.customer,
      recordId: 'c1',
      data: {'id': 'c1', 'name': 'Business Record'},
      isNew: true,
    );

    final record = await storage.localRecords.getRecord(scope, SyncEntity.customer, 'c1');
    expect(record, isNotNull);
    expect(record!.data['name'], 'Business Record');
  });

  test('Multi-select selection, select all, and multi-record actions', () async {
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.customer,
      recordId: 'c1',
      data: {'id': 'c1', 'name': 'Cust 1'},
      isNew: true,
    );
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.customer,
      recordId: 'c2',
      data: {'id': 'c2', 'name': 'Cust 2'},
      isNew: true,
    );

    final reader = UnsyncedRecordsReader(storage);
    final rows = await reader.load();

    final controller = SyncRecordsController(
      source: Stream.value(rows),
    );
    controller.onInit();
    await Future<void>.delayed(Duration.zero);

    expect(controller.pendingCount, 2);
    expect(controller.hasSelection, isFalse);

    final firstKey = controller.pendingRows.first.key;
    controller.selectRow(firstKey);
    expect(controller.hasSelection, isTrue);
    expect(controller.isRowSelected(firstKey), isTrue);

    controller.toggleSelectAll();
    expect(controller.isModelAllSelected, isTrue);
    expect(controller.selectedRecordKeys.length, 2);

    controller.clearSelection();
    expect(controller.hasSelection, isFalse);

    controller.onClose();
  });

  test('Deleting a pending record (isNew) removes it completely', () async {
    await storage.localRecords.saveRecord(
      scope,
      entityType: SyncEntity.customer,
      recordId: 'c1',
      data: {'id': 'c1'},
      isNew: true,
    );

    final recordBefore = await storage.localRecords.getRecord(scope, SyncEntity.customer, 'c1');
    expect(recordBefore, isNotNull);
    expect(recordBefore!.isNew, isTrue);

    await storage.queue.remove(scope.workspaceId, SyncEntity.customer, 'c1');
    await storage.records.delete(scope.workspaceId, SyncEntity.customer, 'c1');

    final recordAfter = await storage.localRecords.getRecord(scope, SyncEntity.customer, 'c1');
    expect(recordAfter, isNull);
  });
}
