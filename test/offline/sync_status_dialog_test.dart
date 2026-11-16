import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/features/home/controller/sync_records_controller.dart';
import 'package:krishi_karobar/features/home/controller/sync_status_controller.dart';
import 'package:krishi_karobar/features/home/screen/sync_records_screen.dart';
import 'package:krishi_karobar/features/home/widgets/sync_status_dialog.dart';
import 'package:krishi_karobar/offline/offline_constants.dart';
import 'package:krishi_karobar/offline/sync/unsynced_records_reader.dart';
import 'package:krishi_karobar/utils/helper/helpers.dart';

UnsyncedRecordRow _row(
  String id, {
  String status = QueueStatus.pending,
  String? error,
  String? conflictId,
}) {
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
    conflictId: conflictId,
  );
}

Future<void> _pump(
  WidgetTester tester,
  SyncStatusKind kind,
  Stream<List<UnsyncedRecordRow>> source,
) async {
  Get.put(SyncRecordsController(
    kind: kind,
    source: source,
    customerName: (_) => 'Ram Customer',
    vehicleName: (_) => 'BA 1 KHA 1',
  ));
  await tester.pumpWidget(
    GetMaterialApp(home: Scaffold(body: SyncStatusDialog())),
  );
  await tester.pump();
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  tearDown(Get.reset);

  testWidgets('Sync Records screen shows tabs and pending records', (tester) async {
    await _pump(tester, SyncStatusKind.offline,
        Stream.value([_row('a1', error: 'No network')]));

    expect(find.text('Sync Records'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Failed (0)'), findsOneWidget);
    expect(find.text('Conflict (0)'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('No network'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('Failed tab shows failed records', (tester) async {
    final controller = SyncRecordsController(
      kind: SyncStatusKind.waiting,
      source: Stream.value([_row('a1', status: QueueStatus.failed, error: 'Permission denied')]),
      customerName: (_) => 'Ram Customer',
      vehicleName: (_) => 'BA 1 KHA 1',
    );
    Get.put(controller);
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SyncRecordsScreen())),
    );
    await tester.pump();

    expect(find.text('Pending (0)'), findsOneWidget);
    expect(find.text('Failed (1)'), findsOneWidget);

    await tester.tap(find.text('Failed (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Failed'), findsOneWidget); // Table cell status text
    expect(find.textContaining('Permission denied'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('Online with nothing unsynced shows empty state', (tester) async {
    await _pump(tester, SyncStatusKind.online, Stream.value(const []));

    expect(find.text('Sync Records'), findsOneWidget);
    expect(find.text('Pending (0)'), findsOneWidget);
    expect(find.text('No pending records waiting to sync.'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('the table refreshes when the source emits again', (tester) async {
    final source = StreamController<List<UnsyncedRecordRow>>();
    addTearDown(source.close);
    await _pump(tester, SyncStatusKind.waiting, source.stream);

    source.add([_row('a1')]);
    await tester.pump();
    expect(find.text('Pending (1)'), findsOneWidget);

    source.add([_row('a1'), _row('a2')]);
    await tester.pump();
    expect(find.text('Pending (2)'), findsOneWidget);
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

  testWidgets('uTableCell keeps the cell size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: uTableCell(const Text('x'), 120))),
    );

    final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(box.width, 120);
    expect(box.height, 30);
    await _finish(tester);
  });
}
