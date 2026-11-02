import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_karobar/models/user_types.dart';
import 'package:krishi_karobar/offline/core/workspace_access.dart';
import 'package:krishi_karobar/offline/core/workspace_scope.dart';
import 'package:krishi_karobar/offline/data/local_record_repository.dart';
import 'package:krishi_karobar/offline/offline_constants.dart';
import 'package:krishi_karobar/offline/offline_exceptions.dart';
import 'package:krishi_karobar/offline/offline_models.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

const _serverUpdatedAt = '2026-09-01T00:00:00.000Z';
const _paymentTime = '2026-10-31T00:00:00.000Z';

Map<String, Object?> _activity(
  String id, {
  String customerId = 'c1',
  int amount = 1000,
  int paidAmount = 0,
  String updatedAt = _serverUpdatedAt,
}) =>
    {
      'id': id,
      'uId': 'A-$id',
      'customerId': customerId,
      'vehicleId': 'v1',
      'serviceId': 's1',
      'amount': amount,
      'paidAmount': paidAmount,
      'dueAmount': amount - paidAmount,
      'status': paidAmount > 0 ? 'partial' : 'due',
      'updatedAt': updatedAt,
    };

Map<String, Object?> _payment(String id, {String customerId = 'c1'}) => {
      'id': id,
      'uId': 'P-$id',
      'customerId': customerId,
      'amount': 500,
      'discount': 0,
      'paymentMethod': 'cash',
      'createdAt': _paymentTime,
    };

/// Adds [extra] to the paid amount, like PaymentController's builder.
Map<String, Object?> Function(Map<String, Object?>) _pay(int extra) {
  return (base) {
    final amount = base['amount'] as int;
    final paid = (base['paidAmount'] as int) + extra;
    if (paid > amount) {
      throw const OfflineDataException.invalid(
        message: 'Payment exceeds activity amount.',
      );
    }
    return {
      'paidAmount': paid,
      'dueAmount': amount - paid,
      'status': paid >= amount ? 'paid' : 'partial',
      'updatedAt': _paymentTime,
    };
  };
}

void main() {
  late Database db;
  late OfflineStorage storage;
  late LocalRecordRepository repo;
  late WorkspaceScope scope;
  var dbCounter = 0;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('payment_${dbCounter++}.db');
    storage = OfflineStorage.forDatabase(db);
    repo = storage.localRecords;
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

  tearDown(() async => db.close());

  Future<LocalRecord?> record(String type, String id) =>
      storage.records.get(scope.workspaceId, type, id);

  Future<SyncQueueEntry?> queued(String type, String id) =>
      storage.queue.get(scope.workspaceId, type, id);

  Future<void> seedLocalActivity(String id, {int paid = 0}) async {
    await repo.saveRecord(
      scope,
      entityType: SyncEntity.activity,
      recordId: id,
      data: _activity(id, paidAmount: paid),
      isNew: true,
    );
  }

  test('rolls back the payment and every activity change when one settlement fails',
      () async {
    await seedLocalActivity('a1');

    await expectLater(
      repo.savePaymentWithSettlements(
        scope,
        paymentId: 'p1',
        payment: _payment('p1'),
        settlements: [
          ActivitySettlement(activityId: 'a1', buildPatch: _pay(500)),
          // Overpays a 1000 activity that already has 800 paid: throws.
          ActivitySettlement(
            activityId: 'a2',
            serverBase: _activity('a2', paidAmount: 800),
            buildPatch: _pay(500),
          ),
        ],
      ),
      throwsA(isA<OfflineDataException>()),
    );

    expect(await record(SyncEntity.payment, 'p1'), isNull);
    expect(await queued(SyncEntity.payment, 'p1'), isNull);
    expect(await record(SyncEntity.activity, 'a2'), isNull);

    final a1 = await record(SyncEntity.activity, 'a1');
    expect(a1!.data['paidAmount'], 0);
    expect(a1.revision, 1);
    expect((await queued(SyncEntity.activity, 'a1'))!.operation,
        SyncOperation.create);
  });

  test('pays an activity outside the cached window using its server copy as base',
      () async {
    await repo.savePaymentWithSettlements(
      scope,
      paymentId: 'p1',
      payment: _payment('p1'),
      settlements: [
        ActivitySettlement(
          activityId: 'old',
          serverBase: _activity('old', paidAmount: 200),
          buildPatch: _pay(500),
        ),
      ],
    );

    final old = await record(SyncEntity.activity, 'old');
    expect(old!.data['paidAmount'], 700);
    expect(old.data['dueAmount'], 300);
    expect(old.isNew, isFalse);
    expect(old.baseUpdatedAt, _serverUpdatedAt);
    expect((await queued(SyncEntity.activity, 'old'))!.operation,
        SyncOperation.update);

    expect((await record(SyncEntity.payment, 'p1'))!.isNew, isTrue);
    expect((await queued(SyncEntity.payment, 'p1'))!.operation,
        SyncOperation.create);
  });

  test('settles against the local balance, which already holds earlier unsynced payments',
      () async {
    await seedLocalActivity('a1');

    await repo.savePaymentWithSettlements(
      scope,
      paymentId: 'p1',
      payment: _payment('p1'),
      settlements: [ActivitySettlement(activityId: 'a1', buildPatch: _pay(500))],
    );
    await repo.savePaymentWithSettlements(
      scope,
      paymentId: 'p2',
      payment: _payment('p2'),
      settlements: [
        // The stale server copy says 0 paid; the local record must win.
        ActivitySettlement(
          activityId: 'a1',
          serverBase: _activity('a1'),
          buildPatch: _pay(300),
        ),
      ],
    );

    expect((await record(SyncEntity.activity, 'a1'))!.data['paidAmount'], 800);

    // A third payment that would exceed the amount is refused whole.
    await expectLater(
      repo.savePaymentWithSettlements(
        scope,
        paymentId: 'p3',
        payment: _payment('p3'),
        settlements: [ActivitySettlement(activityId: 'a1', buildPatch: _pay(300))],
      ),
      throwsA(isA<OfflineDataException>()),
    );
    expect(await record(SyncEntity.payment, 'p3'), isNull);
    expect((await record(SyncEntity.activity, 'a1'))!.data['paidAmount'], 800);
  });

  test('refuses an activity that belongs to another customer', () async {
    await expectLater(
      repo.savePaymentWithSettlements(
        scope,
        paymentId: 'p1',
        payment: _payment('p1'),
        settlements: [
          ActivitySettlement(
            activityId: 'foreign',
            serverBase: _activity('foreign', customerId: 'someone-else'),
            buildPatch: _pay(500),
          ),
        ],
      ),
      throwsA(isA<OfflineDataException>()),
    );

    expect(await record(SyncEntity.payment, 'p1'), isNull);
    expect(await record(SyncEntity.activity, 'foreign'), isNull);
  });

  test('refuses a settlement that has no local record and no server base', () async {
    await expectLater(
      repo.savePaymentWithSettlements(
        scope,
        paymentId: 'p1',
        payment: _payment('p1'),
        settlements: [ActivitySettlement(activityId: 'ghost', buildPatch: _pay(500))],
      ),
      throwsA(isA<OfflineDataException>()),
    );
    expect(await record(SyncEntity.payment, 'p1'), isNull);
  });

  test('never applies the same payment id twice', () async {
    await seedLocalActivity('a1');
    final settlements = [ActivitySettlement(activityId: 'a1', buildPatch: _pay(500))];

    await repo.savePaymentWithSettlements(scope,
        paymentId: 'p1', payment: _payment('p1'), settlements: settlements);

    await expectLater(
      repo.savePaymentWithSettlements(scope,
          paymentId: 'p1', payment: _payment('p1'), settlements: settlements),
      throwsA(isA<OfflineDataException>()),
    );
    expect((await record(SyncEntity.activity, 'a1'))!.data['paidAmount'], 500);
  });

  test('saveNewRecords stores everything or nothing', () async {
    await seedLocalActivity('dup');

    await expectLater(
      repo.saveNewRecords(scope, [
        NewLocalRecord(
          entityType: SyncEntity.payment,
          recordId: 'p9',
          data: _payment('p9'),
        ),
        // Already stored locally: refused AFTER p9 was written in the same
        // transaction, so p9 must be rolled back.
        NewLocalRecord(
          entityType: SyncEntity.activity,
          recordId: 'dup',
          data: _activity('dup'),
        ),
      ]),
      throwsA(isA<OfflineDataException>()),
    );

    expect(await record(SyncEntity.payment, 'p9'), isNull);
    expect(await queued(SyncEntity.payment, 'p9'), isNull);

    await repo.saveNewRecords(scope, [
      NewLocalRecord(
        entityType: SyncEntity.payment,
        recordId: 'p10',
        data: _payment('p10'),
      ),
      NewLocalRecord(
        entityType: SyncEntity.activity,
        recordId: 'new-activity',
        data: _activity('new-activity'),
      ),
    ]);
    expect(await record(SyncEntity.payment, 'p10'), isNotNull);
    expect(await record(SyncEntity.activity, 'new-activity'), isNotNull);
  });
}
