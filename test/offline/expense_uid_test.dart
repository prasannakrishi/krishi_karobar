import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_karobar/offline/offline_exceptions.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:krishi_karobar/offline/uid/expense_uid_format.dart';
import 'package:krishi_karobar/offline/uid/expense_uid_remote.dart';
import 'package:krishi_karobar/offline/uid/expense_uid_service.dart';
import 'package:krishi_karobar/utils/helper/nepali_date_time.dart';
import 'package:sembast/sembast_memory.dart';

/// Server counters with the same semantics as the Firebase transactions.
class FakeRemote implements ExpenseUidRemote {
  final Map<String, int> counters = {};
  Object? failWith;
  int calls = 0;

  String _key(String code, int year) => '$code/$year';

  @override
  Future<int> allocateNext({
    required String vehicleCode,
    required int nepaliYear,
  }) async {
    calls++;
    if (failWith != null) throw failWith!;
    final key = _key(vehicleCode, nepaliYear);
    return counters[key] = (counters[key] ?? 0) + 1;
  }

  @override
  Future<ExpenseSequenceClaim> claim({
    required String vehicleCode,
    required int nepaliYear,
    required int sequence,
  }) async {
    calls++;
    if (failWith != null) throw failWith!;
    final key = _key(vehicleCode, nepaliYear);
    final base = counters[key] ?? 0;
    final value = base < sequence ? sequence : base + 1;
    counters[key] = value;
    return ExpenseSequenceClaim(sequence: value, kept: value == sequence);
  }
}

// Year 2083 / 2093 / 2084 selected by the Gregorian year of the test date,
// so tests do not depend on the calendar library.
int fakeYear(DateTime d) => d.year;

final y2083 = DateTime(2083, 5, 1);
final y2093 = DateTime(2093, 5, 1);
final y2084 = DateTime(2084, 5, 1);

Future<({OfflineStorage storage, FakeRemote remote, ExpenseUidService service})>
    setup({bool online = true}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'expense_uid_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final storage = OfflineStorage.forDatabase(db);
  final remote = FakeRemote();
  final service = ExpenseUidService(
    sequences: storage.sequences,
    remote: remote,
    nepaliYearOf: fakeYear,
    isOnline: () async => online,
  );
  return (storage: storage, remote: remote, service: service);
}

void main() {
  group('format', () {
    test('builds EV01-30001 for vehicle V01, year 2083, sequence 1', () {
      final uid = ExpenseUidFormat.build(
        vehicleCode: 'V01',
        nepaliYear: 2083,
        sequence: 1,
      );
      expect(uid.uId, 'EV01-30001');
    });

    test('2083 and 2093 show the same digit but keep their own year', () {
      final a = ExpenseUidFormat.build(
        vehicleCode: 'V01',
        nepaliYear: 2083,
        sequence: 7,
      );
      final b = ExpenseUidFormat.build(
        vehicleCode: 'V01',
        nepaliYear: 2093,
        sequence: 7,
      );
      expect(a.uId, b.uId);
      expect(a.nepaliYear, isNot(b.nepaliYear));
    });

    test('the next Nepali year changes the digit and the vehicle code', () {
      expect(
        ExpenseUidFormat.build(
          vehicleCode: 'V01',
          nepaliYear: 2084,
          sequence: 1,
        ).uId,
        'EV01-40001',
      );
      expect(
        ExpenseUidFormat.build(
          vehicleCode: 'v02',
          nepaliYear: 2083,
          sequence: 12,
        ).uId,
        'EV02-30012',
      );
    });

    test('sequences above 9999 keep growing, never truncate', () {
      expect(
        ExpenseUidFormat.build(
          vehicleCode: 'V01',
          nepaliYear: 2083,
          sequence: 12345,
        ).uId,
        'EV01-312345',
      );
      expect(ExpenseUidFormat.tryParse('EV01-312345')!.sequence, 12345);
    });

    test('parse round trips and rejects other formats', () {
      final parts = ExpenseUidFormat.tryParse('EV01-30026')!;
      expect(parts.vehicleCode, 'V01');
      expect(parts.yearDigit, 3);
      expect(parts.sequence, 26);

      expect(ExpenseUidFormat.tryParse('E6-0001'), isNull);
      expect(ExpenseUidFormat.tryParse('RT01-30001'), isNull);
      expect(ExpenseUidFormat.isExpenseUid('EV01-30001'), true);
    });

    test('invalid vehicle codes, years and sequences are rejected', () {
      expect(
        () => ExpenseUidFormat.normalizeVehicleCode('V-01'),
        throwsA(isA<ExpenseUidException>()),
      );
      expect(
        () => ExpenseUidFormat.normalizeVehicleCode('  '),
        throwsA(isA<ExpenseUidException>()),
      );
      expect(
        () => ExpenseUidFormat.build(
          vehicleCode: 'V01',
          nepaliYear: 1999,
          sequence: 1,
        ),
        throwsA(isA<ExpenseUidException>()),
      );
      expect(
        () => ExpenseUidFormat.build(
          vehicleCode: 'V01',
          nepaliYear: 2083,
          sequence: 0,
        ),
        throwsA(isA<ExpenseUidException>()),
      );
    });

    test('default year resolver maps 6 Oct 2026 to Nepali year 2083', () {
      expect(toNepaliCalendar(DateTime.utc(2026, 10, 6)).year, 2083);
    });
  });

  group('vehicle code', () {
    test('is V + serial from the vehicle uId', () {
      expect(ExpenseUidFormat.vehicleCodeFromVehicleUId('VT3-01'), 'V01');
      expect(ExpenseUidFormat.vehicleCodeFromVehicleUId('VT6-0001'), 'V01');
      expect(ExpenseUidFormat.vehicleCodeFromVehicleUId('VH6-0012'), 'V12');
      expect(ExpenseUidFormat.vehicleCodeFromVehicleUId('vt6-0123'), 'V123');
    });

    test('rejects values that are not vehicle uIds', () {
      for (final bad in ['', 'T6-0001', 'VT6', 'VT6-0000', 'VT-01']) {
        expect(
          () => ExpenseUidFormat.vehicleCodeFromVehicleUId(bad),
          throwsA(isA<ExpenseUidException>()),
          reason: bad,
        );
      }
    });

    test('known limitation: tractor and harvester with one serial share a code',
        () {
      expect(
        ExpenseUidFormat.vehicleCodeFromVehicleUId('VT3-01'),
        ExpenseUidFormat.vehicleCodeFromVehicleUId('VH3-01'),
      );
    });
  });

  group('offline allocation', () {
    test('starts at 1 and counts up per vehicle and year', () async {
      final t = await setup(online: false);

      final a = await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      final b = await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      final other =
          await t.service.allocate(vehicleCode: 'V02', createdAt: y2083);

      expect([a.uId, b.uId, other.uId], [
        'EV01-30001',
        'EV01-30002',
        'EV02-30001',
      ]);
      expect(t.remote.calls, 0);
    });

    test('2083 and 2093 never share a counter', () async {
      final t = await setup(online: false);

      await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      final later =
          await t.service.allocate(vehicleCode: 'V01', createdAt: y2093);

      expect(later.uId, 'EV01-30001');
      expect(later.nepaliYear, 2093);
    });

    test('the sequence restarts in a new Nepali year', () async {
      final t = await setup(online: false);

      await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      final next =
          await t.service.allocate(vehicleCode: 'V01', createdAt: y2084);

      expect(next.uId, 'EV01-40001');
    });

    test('continues after the last known server sequence', () async {
      final t = await setup(online: false);
      await t.storage.sequences
          .recordServerSequence('expense', 'V01', '2083', 25);

      final uid = await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);

      expect(uid.uId, 'EV01-30026');
    });
  });

  group('online allocation', () {
    test('uses the server counter and teaches the local counter', () async {
      final t = await setup();
      t.remote.counters['V01/2083'] = 10;

      final online =
          await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      expect(online.uId, 'EV01-30011');

      final offline = await ExpenseUidService(
        sequences: t.storage.sequences,
        remote: t.remote,
        nepaliYearOf: fakeYear,
        isOnline: () async => false,
      ).allocate(vehicleCode: 'V01', createdAt: y2083);
      expect(offline.uId, 'EV01-30012');
    });

    test('stays local while unsynced provisional numbers exist', () async {
      final t = await setup(online: false);
      await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);

      final online = ExpenseUidService(
        sequences: t.storage.sequences,
        remote: t.remote,
        nepaliYearOf: fakeYear,
        isOnline: () async => true,
      );
      final uid = await online.allocate(vehicleCode: 'V01', createdAt: y2083);

      expect(uid.uId, 'EV01-30003');
      expect(t.remote.calls, 0);
    });

    test('falls back to local when the server cannot be reached', () async {
      final t = await setup();
      t.remote.failWith = TimeoutException('no route');

      final uid = await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);

      expect(uid.uId, 'EV01-30001');
    });

    test('other failures are not swallowed', () async {
      final t = await setup();
      t.remote.failWith = const ExpenseUidException.counterUnreadable();

      expect(
        () => t.service.allocate(vehicleCode: 'V01', createdAt: y2083),
        throwsA(isA<ExpenseUidException>()),
      );
    });
  });

  group('reconcile at sync', () {
    test('a free provisional number is kept', () async {
      final t = await setup(online: false);
      t.remote.counters['V01/2083'] = 25;
      await t.storage.sequences
          .recordServerSequence('expense', 'V01', '2083', 25);
      final provisional =
          await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);

      final result = await t.service.reconcile(
        provisionalUId: provisional.uId,
        vehicleCode: 'V01',
        createdAt: y2083,
      );

      expect(provisional.uId, 'EV01-30026');
      expect(result.changed, false);
      expect(result.uId, 'EV01-30026');
      expect(t.remote.counters['V01/2083'], 26);
    });

    test('a taken number is replaced by the next free one', () async {
      final t = await setup(online: false);
      final provisional =
          await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      expect(provisional.uId, 'EV01-30001');

      // Another device already used numbers up to 30 on the server.
      t.remote.counters['V01/2083'] = 30;

      final result = await t.service.reconcile(
        provisionalUId: provisional.uId,
        vehicleCode: 'V01',
        createdAt: y2083,
      );

      expect(result.changed, true);
      expect(result.uId, 'EV01-30031');
      expect(result.previousUId, 'EV01-30001');

      // The local counter never hands out a number the server owns.
      final next = await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      expect(next.uId, 'EV01-30032');
    });

    test('several provisional numbers are claimed in order', () async {
      final t = await setup(online: false);
      final a = await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      final b = await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      t.remote.counters['V01/2083'] = 1; // someone else took number 1

      final ra = await t.service.reconcile(
        provisionalUId: a.uId,
        vehicleCode: 'V01',
        createdAt: y2083,
      );
      final rb = await t.service.reconcile(
        provisionalUId: b.uId,
        vehicleCode: 'V01',
        createdAt: y2083,
      );

      expect(ra.uId, 'EV01-30002');
      expect(rb.uId, 'EV01-30003');
      expect({ra.uId, rb.uId}.length, 2);
    });

    test('a uId that does not match vehicle or year is rejected', () async {
      final t = await setup(online: false);

      expect(
        () => t.service.reconcile(
          provisionalUId: 'EV01-40001',
          vehicleCode: 'V01',
          createdAt: y2083,
        ),
        throwsA(isA<ExpenseUidException>()),
      );
      expect(
        () => t.service.reconcile(
          provisionalUId: 'EV02-30001',
          vehicleCode: 'V01',
          createdAt: y2083,
        ),
        throwsA(isA<ExpenseUidException>()),
      );
      expect(
        () => t.service.reconcile(
          provisionalUId: 'E6-0001',
          vehicleCode: 'V01',
          createdAt: y2083,
        ),
        throwsA(isA<ExpenseUidException>()),
      );
      expect(t.remote.calls, 0);
    });

    test('a server failure leaves the counters untouched', () async {
      final t = await setup(online: false);
      final provisional =
          await t.service.allocate(vehicleCode: 'V01', createdAt: y2083);
      t.remote.failWith = TimeoutException('offline');

      await expectLater(
        () => t.service.reconcile(
          provisionalUId: provisional.uId,
          vehicleCode: 'V01',
          createdAt: y2083,
        ),
        throwsA(isA<TimeoutException>()),
      );

      final local = await t.storage.sequences.peek('expense', 'V01', '2083');
      expect(local!.lastKnownServerSequence, 0);
    });
  });
}
