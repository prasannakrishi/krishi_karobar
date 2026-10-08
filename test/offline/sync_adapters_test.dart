import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_karobar/offline/core/workspace_scope.dart';
import 'package:krishi_karobar/offline/offline_constants.dart';
import 'package:krishi_karobar/offline/offline_exceptions.dart';
import 'package:krishi_karobar/offline/offline_models.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:krishi_karobar/offline/sync/adapters/activity_sync_adapter.dart';
import 'package:krishi_karobar/offline/sync/adapters/customer_sync_adapter.dart';
import 'package:krishi_karobar/offline/sync/adapters/expense_sync_adapter.dart';
import 'package:krishi_karobar/offline/sync/record_comparator.dart';
import 'package:krishi_karobar/offline/sync/sync_adapter.dart';
import 'package:krishi_karobar/offline/sync/sync_adapter_registry.dart';
import 'package:krishi_karobar/offline/uid/expense_uid_remote.dart';
import 'package:krishi_karobar/offline/uid/expense_uid_service.dart';
import 'package:sembast/sembast_memory.dart';

class FakeCounterRemote implements ExpenseUidRemote {
  final Map<String, int> counters = {};

  @override
  Future<int> allocateNext({
    required String vehicleCode,
    required int nepaliYear,
  }) async {
    final key = '$vehicleCode/$nepaliYear';
    return counters[key] = (counters[key] ?? 0) + 1;
  }

  @override
  Future<ExpenseSequenceClaim> claim({
    required String vehicleCode,
    required int nepaliYear,
    required int sequence,
  }) async {
    final key = '$vehicleCode/$nepaliYear';
    final base = counters[key] ?? 0;
    final value = base < sequence ? sequence : base + 1;
    counters[key] = value;
    return ExpenseSequenceClaim(sequence: value, kept: value == sequence);
  }
}

LocalRecord record(
  String type,
  String id,
  Map<String, Object?> data, {
  bool isNew = true,
}) {
  final now = DateTime.utc(2026, 10, 6);
  return LocalRecord(
    workspaceId: 'dev|u1|v1',
    entityType: type,
    recordId: id,
    data: data,
    isNew: isNew,
    revision: 1,
    createdAt: now,
    updatedAt: now,
  );
}

Future<SyncAdapterContext> context({
  Map<String, Map<String, Object?>> references = const {},
  List<String>? sequenceCalls,
  List<Map<String, String>>? activityCalls,
  FakeCounterRemote? remote,
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'adapters_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final storage = OfflineStorage.forDatabase(db);

  return SyncAdapterContext(
    scope: const WorkspaceScope(
      environment: 'dev',
      ownerUserId: 'u1',
      authUid: 'a1',
      vehicleId: 'v1',
    ),
    reference: (type, id) async => references['$type|$id'],
    expenseUid: ExpenseUidService(
      sequences: storage.sequences,
      remote: remote ?? FakeCounterRemote(),
      nepaliYearOf: (d) => d.year,
    ),
    generateSequence: (prefix) async {
      sequenceCalls?.add(prefix);
      return '${prefix}6-0042';
    },
    generateActivityUid: ({
      required String serviceType,
      required String vehicleUId,
    }) async {
      activityCalls?.add({'service': serviceType, 'vehicle': vehicleUId});
      return 'RT0001-610001';
    },
  );
}

void main() {
  group('PendingUid', () {
    test('is recognisable and derived from the record id', () {
      final uid = PendingUid.forRecord('0a1b2c3d-1111-2222-3333-444455556666');
      expect(uid, 'PENDING-0A1B2C3D');
      expect(PendingUid.isPending(uid), true);
      expect(PendingUid.isPending('C6-0001'), false);
      expect(PendingUid.isPending(null), false);
    });
  });

  group('RecordComparator', () {
    test('null equals a missing field; numbers compare by value', () {
      expect(
        RecordComparator.matches(
          expected: {'a': null, 'amount': 5},
          actual: {'amount': 5.0},
        ),
        true,
      );
    });

    test('ISO dates compare as instants', () {
      expect(
        RecordComparator.sameValue(
          '2026-10-06T10:00:00.000Z',
          '2026-10-06T10:00:00Z',
        ),
        true,
      );
      expect(
        RecordComparator.sameValue(
          '2026-10-06T10:00:00.000Z',
          '2026-10-06T10:00:01.000Z',
        ),
        false,
      );
    });

    test('reports the differing fields only', () {
      final diff = RecordComparator.differences(
        expected: {'id': 'x', 'amount': 5000, 'status': 'due'},
        actual: {'id': 'x', 'amount': 5500, 'status': 'due', 'extra': 1},
      );
      expect(diff.map((d) => d.field), ['amount']);
      expect(diff.single.local, 5000);
      expect(diff.single.server, 5500);
    });

    test('a missing server record differs in every set field', () {
      final diff = RecordComparator.differences(
        expected: {'id': 'x', 'note': null},
        actual: null,
      );
      expect(diff.map((d) => d.field), ['id']);
    });

    test('nested maps and lists compare deeply', () {
      expect(
        RecordComparator.sameValue(
          {'a': [1, 2], 'b': {'c': 1}},
          {'a': [1, 2], 'b': {'c': 1.0}},
        ),
        true,
      );
      expect(
        RecordComparator.sameValue({'a': [1, 2]}, {'a': [1, 3]}),
        false,
      );
    });
  });

  group('registry', () {
    test('orders parents before children', () {
      final order = SyncAdapterRegistry.standard()
          .ordered
          .map((a) => a.entityType)
          .toList();

      expect(order, [
        SyncEntity.customer,
        SyncEntity.activity,
        SyncEntity.activityLocation,
        SyncEntity.expense,
        SyncEntity.expenseLocation,
      ]);
    });

    test('an unknown type is an error, never silently skipped', () {
      final registry = SyncAdapterRegistry.standard();
      expect(registry.supports(SyncEntity.user), false);
      expect(() => registry.adapterFor('user'), throwsStateError);
    });

    test('a later adapter can be registered without other changes', () {
      final registry = SyncAdapterRegistry([
        ...SyncAdapterRegistry.standard().ordered,
        const _UserAdapter(),
      ]);
      expect(registry.supports(SyncEntity.user), true);
    });
  });

  group('customer adapter', () {
    const adapter = CustomerSyncAdapter();

    test('a pending uId is replaced by the existing generator', () async {
      final calls = <String>[];
      final ctx = await context(sequenceCalls: calls);
      final r = record(SyncEntity.customer, 'c1', {
        'id': 'c1',
        'uId': PendingUid.forRecord('c1'),
        'name': 'Ram',
      });

      final result = await adapter.resolveUid(ctx, r, uidClaimed: false);

      expect(result!.uId, 'C6-0042');
      expect(calls, ['C']);
    });

    test('an existing uId is left alone', () async {
      final calls = <String>[];
      final ctx = await context(sequenceCalls: calls);
      final r = record(SyncEntity.customer, 'c1', {
        'id': 'c1',
        'uId': 'C6-0001',
        'name': 'Ram',
      });

      expect(await adapter.resolveUid(ctx, r, uidClaimed: false), isNull);
      expect(calls, isEmpty);
    });

    test('a payload with a pending uId is refused', () {
      final r = record(SyncEntity.customer, 'c1', {
        'id': 'c1',
        'uId': PendingUid.forRecord('c1'),
      });

      expect(
        () => adapter.buildCreatePayload(r),
        throwsA(isA<SyncPreparationException>()),
      );
    });

    test('update patch never carries the immutable fields', () {
      final r = record(
        SyncEntity.customer,
        'c1',
        {
          'id': 'c1',
          'uId': 'C6-0001',
          'name': 'Ram',
          'createdAt': '2026-10-01T00:00:00.000Z',
          'createdBy': 'u1',
        },
        isNew: false,
      );

      final patch = adapter.buildUpdatePatch(r);
      expect(patch.containsKey('id'), false);
      expect(patch.containsKey('createdAt'), false);
      expect(patch.containsKey('createdBy'), false);
      expect(patch['name'], 'Ram');
    });
  });

  group('activity adapter', () {
    const adapter = ActivitySyncAdapter();

    test('depends on its customer when it has one', () {
      final withCustomer = record(SyncEntity.activity, 'a1', {
        'id': 'a1',
        'customerId': 'c1',
      });
      final withoutCustomer = record(SyncEntity.activity, 'a2', {
        'id': 'a2',
        'customerId': '',
      });

      expect(adapter.parentsOf(withCustomer).single.recordId, 'c1');
      expect(
        adapter.parentsOf(withCustomer).single.entityType,
        SyncEntity.customer,
      );
      expect(adapter.parentsOf(withoutCustomer), isEmpty);
    });

    test('pending uId uses service name and vehicle uId', () async {
      final calls = <Map<String, String>>[];
      final ctx = await context(
        activityCalls: calls,
        references: {
          'service|s1': {'name': 'Rotavator'},
          'vehicle|v1': {'uId': 'VT3-01'},
        },
      );
      final r = record(SyncEntity.activity, 'a1', {
        'id': 'a1',
        'uId': PendingUid.forRecord('a1'),
        'serviceId': 's1',
        'vehicleId': 'v1',
      });

      final result = await adapter.resolveUid(ctx, r, uidClaimed: false);

      expect(result!.uId, 'RT0001-610001');
      expect(calls.single, {'service': 'Rotavator', 'vehicle': 'VT3-01'});
    });

    test('missing reference data is reported, not guessed', () async {
      final ctx = await context(
        references: {
          'service|s1': {'name': 'Rotavator'},
        },
      );
      final r = record(SyncEntity.activity, 'a1', {
        'id': 'a1',
        'uId': PendingUid.forRecord('a1'),
        'serviceId': 's1',
        'vehicleId': 'v1',
      });

      expect(
        () => adapter.resolveUid(ctx, r, uidClaimed: false),
        throwsA(isA<SyncPreparationException>()),
      );
    });

    test('an already final uId is untouched', () async {
      final ctx = await context();
      final r = record(SyncEntity.activity, 'a1', {
        'id': 'a1',
        'uId': 'RT0001-610009',
      });

      expect(await adapter.resolveUid(ctx, r, uidClaimed: false), isNull);
    });
  });

  group('expense adapter', () {
    const adapter = ExpenseSyncAdapter();

    Map<String, Object?> expense(String uId) => {
          'id': 'e1',
          'uId': uId,
          'activityId': 'a1',
          'createdAt': DateTime(2083, 5, 1).toUtc().toIso8601String(),
        };

    test('depends on its activity when it has one', () {
      final r = record(SyncEntity.expense, 'e1', expense('EV01-30001'));
      expect(adapter.parentsOf(r).single.entityType, SyncEntity.activity);
      expect(adapter.parentsOf(r).single.recordId, 'a1');
    });

    test('a free provisional uId is kept', () async {
      final remote = FakeCounterRemote()..counters['V01/2083'] = 25;
      final ctx = await context(remote: remote);
      final r = record(SyncEntity.expense, 'e1', expense('EV01-30026'));

      final result = await adapter.resolveUid(ctx, r, uidClaimed: false);

      expect(result!.uId, 'EV01-30026');
      expect(result.changed, false);
    });

    test('a taken provisional uId becomes the next free one', () async {
      final remote = FakeCounterRemote()..counters['V01/2083'] = 30;
      final ctx = await context(remote: remote);
      final r = record(SyncEntity.expense, 'e1', expense('EV01-30001'));

      final result = await adapter.resolveUid(ctx, r, uidClaimed: false);

      expect(result!.uId, 'EV01-30031');
      expect(result.changed, true);
    });

    test('an already claimed uId is not claimed twice', () async {
      final remote = FakeCounterRemote();
      final ctx = await context(remote: remote);
      final r = record(SyncEntity.expense, 'e1', expense('EV01-30001'));

      expect(await adapter.resolveUid(ctx, r, uidClaimed: true), isNull);
      expect(remote.counters, isEmpty);
    });

    test('older expense uIds are left alone', () async {
      final remote = FakeCounterRemote();
      final ctx = await context(remote: remote);
      final r = record(SyncEntity.expense, 'e1', expense('E6-0001'));

      expect(await adapter.resolveUid(ctx, r, uidClaimed: false), isNull);
      expect(remote.counters, isEmpty);
    });

    test('a missing createdAt is reported', () async {
      final ctx = await context();
      final r = record(SyncEntity.expense, 'e1', {
        'id': 'e1',
        'uId': 'EV01-30001',
      });

      expect(
        () => adapter.resolveUid(ctx, r, uidClaimed: false),
        throwsA(isA<SyncPreparationException>()),
      );
    });
  });

  group('location adapters', () {
    test('merge writes confirmed by acknowledgement, child of the parent', () {
      final adapters = SyncAdapterRegistry.standard();
      final activity = adapters.adapterFor(SyncEntity.activityLocation);
      final expenseLoc = adapters.adapterFor(SyncEntity.expenseLocation);

      expect(activity.writeMode, SyncWriteMode.merge);
      expect(activity.verification, SyncVerification.writeAcknowledged);
      expect(activity.remotePath, 'activity_locations');
      expect(expenseLoc.remotePath, 'expense_locations');

      final r = record(SyncEntity.activityLocation, 'a1', {
        'startLocation': {'latitude': 1.0},
      });
      final parent = activity.parentsOf(r).single;

      expect(parent.entityType, SyncEntity.activity);
      expect(parent.recordId, 'a1');
      expect(activity.buildCreatePayload(r)['id'], 'a1');
      expect(activity.buildUpdatePatch(r)['startLocation'], isNotNull);
    });
  });

  group('write modes', () {
    test('records use create-if-absent with read-back by default', () {
      final registry = SyncAdapterRegistry.standard();

      for (final type in [
        SyncEntity.customer,
        SyncEntity.activity,
        SyncEntity.expense,
      ]) {
        final adapter = registry.adapterFor(type);
        expect(adapter.writeMode, SyncWriteMode.createIfAbsent, reason: type);
        expect(adapter.verification, SyncVerification.readBack, reason: type);
      }
    });
  });
}

class _UserAdapter extends SyncAdapter {
  const _UserAdapter();

  @override
  String get entityType => SyncEntity.user;

  @override
  String get remotePath => 'users';

  @override
  String? get referenceType => null;

  @override
  int get dependencyRank => 5;
}
