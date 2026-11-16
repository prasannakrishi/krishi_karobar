import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/features/home/controller/sync_status_controller.dart';
import 'package:krishi_karobar/features/home/widgets/sync_status_dialog.dart';
import 'package:krishi_karobar/offline/offline_constants.dart';
import 'package:krishi_karobar/offline/sync/unsynced_records_reader.dart';
import 'package:krishi_karobar/utils/helper/helpers.dart';

UnsyncedRecordRow _row(String id, {String status = QueueStatus.pending, String? error}) {
  return UnsyncedRecordRow(
    entityType: SyncEntity.activity,
    recordId: id,
    status: status,
    operation: SyncOperation.create,
    date: DateTime.utc(2026, 11, 1, 6),
    displayUid: 'PENDING-$id',
    customerId: 'c1',
    vehicleId: 'v1',
    lastAttemptAt: DateTime.utc(2026, 11, 1, 7),
    error: error,
  );
}

Future<void> _pump(
  WidgetTester tester,
  SyncStatusKind kind,
  Stream<List<UnsyncedRecordRow>> source,
) async {
  Get.put(SyncStatusController(
    kind: kind,
    source: source,
    customerName: (_) => 'Ram Customer',
    vehicleName: (_) => 'BA 1 KHA 1',
  ));
  await tester.pumpWidget(
    const GetMaterialApp(home: Scaffold(body: SyncStatusDialog())),
  );
  await tester.pump();
}

/// MarqueeWidget (used by every table cell) loops on `Future.delayed`;
/// unmount it and let the last delay fire so no timer is left pending.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  tearDown(Get.reset);

  testWidgets('Offline shows the unsynced records', (tester) async {
    await _pump(tester, SyncStatusKind.offline,
        Stream.value([_row('a1', error: 'No network')]));

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Ram Customer'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('No network'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('Waiting shows the unsynced records with their status', (tester) async {
    await _pump(tester, SyncStatusKind.waiting,
        Stream.value([_row('a1', status: QueueStatus.failed)]));

    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('Online with nothing unsynced shows the empty state', (tester) async {
    await _pump(tester, SyncStatusKind.online, Stream.value(const []));

    expect(find.text('Online'), findsOneWidget);
    expect(find.text('All records are synced.'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('Offline with nothing queued shows its own empty message', (tester) async {
    await _pump(tester, SyncStatusKind.offline, Stream.value(const []));

    expect(find.textContaining('No unsynced records'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('the table refreshes when the source emits again', (tester) async {
    final source = StreamController<List<UnsyncedRecordRow>>();
    addTearDown(source.close);
    await _pump(tester, SyncStatusKind.waiting, source.stream);

    source.add([_row('a1')]);
    await tester.pump();
    expect(find.text('1 unsynced'), findsOneWidget);

    source.add([_row('a1'), _row('a2')]);
    await tester.pump();
    expect(find.text('2 unsynced'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('a missing optional field does not crash the table', (tester) async {
    final bare = UnsyncedRecordRow(
      entityType: 'something_new',
      recordId: 'x1',
      status: QueueStatus.blocked,
      operation: SyncOperation.update,
      date: DateTime.utc(2026, 11, 1),
    );
    await _pump(tester, SyncStatusKind.waiting, Stream.value([bare]));

    expect(tester.takeException(), isNull);
    expect(find.text('something_new'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('uTableCell keeps the Recent Activity cell size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: uTableCell(const Text('x'), 120))),
    );

    final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(box.width, 120);
    expect(box.height, 30);
    await _finish(tester);
  });
}
