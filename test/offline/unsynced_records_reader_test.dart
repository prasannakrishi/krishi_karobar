import 'package:flutter_test/flutter_test.dart';
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
  late UnsyncedRecordsReader reader;

  Future<void> save(String id, {String entity = SyncEntity.customer}) {
    return storage.localRecords.saveRecord(
      scope,
      entityType: entity,
      recordId: id,
      data: {
        'id': id,
        'uId': 'U-$id',
        'name': 'Name $id',
        'updatedAt': '2026-11-01T00:00:00.000Z',
      },
      isNew: true,
    );
  }

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('unsynced.db');
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
    reader = UnsyncedRecordsReader(storage);
  });

  tearDown(() async {
    await db.close();
  });

  test('empty queue gives an empty list (no Firebase needed)', () async {
    expect(await reader.load(), isEmpty);
  });

  test('lists unsynced records from the local queue only', () async {
    await save('c1');
    await save('a1', entity: SyncEntity.activity);

    final rows = await reader.load();

    expect(rows.map((r) => r.recordId).toSet(), {'c1', 'a1'});
    final customer = rows.firstWhere((r) => r.recordId == 'c1');
    expect(customer.status, QueueStatus.pending);
    expect(customer.displayUid, 'U-c1');
  });

  test('saving the same record twice does not duplicate its row', () async {
    await save('c1');
    await save('c1');

    final rows = await reader.load();

    expect(rows.where((r) => r.recordId == 'c1'), hasLength(1));
  });

  test('a status change shows the actual queue status', () async {
    await save('c1');
    await storage.queue.markSyncing(scope.workspaceId, SyncEntity.customer, 'c1');

    final rows = await reader.load();

    expect(rows.single.status, QueueStatus.syncing);
  });

  test('reading does not change any queue entry', () async {
    await save('c1');
    final before = (await storage.queue.list(scope.workspaceId))
        .map((e) => e.toMap())
        .toList();

    await reader.load();
    await reader.watch().first;

    final after = (await storage.queue.list(scope.workspaceId))
        .map((e) => e.toMap())
        .toList();
    expect(after, before);
  });

  test('watch refreshes when the queue changes', () async {
    final emissions = <int>[];
    final sub = reader.watch().listen((rows) => emissions.add(rows.length));

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await save('c1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await save('c2');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(emissions.first, 0);
    expect(emissions.last, 2);
  });
}
