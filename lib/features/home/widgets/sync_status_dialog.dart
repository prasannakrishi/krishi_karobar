import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../offline/sync/unsynced_records_reader.dart';
import '../../../utils/helper/helpers.dart';
import '../controller/sync_status_controller.dart';

/// Lists the records behind the dashboard sync pill using the same
/// `uDataTable` / `uTableCell` the Recent Activity table is built from.
class SyncStatusDialog extends StatelessWidget {
  const SyncStatusDialog({super.key, this.onSyncNow});

  /// Optional manual sync (the pill used to start one on tap).
  final Future<void> Function()? onSyncNow;

  static const _headerStyle = TextStyle(fontWeight: FontWeight.bold);

  /// Opens the view for [kind]. The controller is read-only and is removed
  /// when the dialog closes.
  static Future<void> show(
    SyncStatusKind kind, {
    Future<void> Function()? onSyncNow,
  }) async {
    if (Get.isRegistered<SyncStatusController>()) {
      Get.delete<SyncStatusController>(force: true);
    }
    Get.put(SyncStatusController(kind: kind));
    try {
      await Get.dialog<void>(SyncStatusDialog(onSyncNow: onSyncNow));
    } finally {
      if (Get.isRegistered<SyncStatusController>()) {
        Get.delete<SyncStatusController>(force: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SyncStatusController>();
    final height = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(controller: controller, onSyncNow: onSyncNow),
              const SizedBox(height: 8),
              Expanded(child: _Body(controller: controller)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onSyncNow});

  final SyncStatusController controller;
  final Future<void> Function()? onSyncNow;

  @override
  Widget build(BuildContext context) {
    final color = controller.color;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color),
          ),
          child: Text(
            controller.title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Obx(
          () => Text(
            '${controller.rows.length} unsynced',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),
        if (onSyncNow != null)
          TextButton(
            onPressed: () => onSyncNow!(),
            child: const Text('Sync now'),
          ),
        IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Get.back<void>(),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final SyncStatusController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.rows.toList();
      final loading = controller.isLoading.value;
      final error = controller.error.value;

      if (loading && rows.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                error,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      controller.emptyMessage,
                      textAlign: TextAlign.center,
                    ),
                  )
                : _table(rows),
          ),
        ],
      );
    });
  }

  Widget _table(List<UnsyncedRecordRow> rows) {
    Widget header(String text, double width, {Alignment? align}) => uTableCell(
          Align(
            alignment: align ?? Alignment.centerLeft,
            child: Text(text, style: SyncStatusDialog._headerStyle),
          ),
          width,
        );

    Widget cell(String text, double width, {Color? color}) => uTableCell(
          Align(
            alignment: Alignment.centerLeft,
            child: Text(text, style: color == null ? null : TextStyle(color: color)),
          ),
          width,
        );

    return uDataTable(
      columns: [
        header('Type', 100),
        header('Record ID / UID', 150),
        header('Customer', 120),
        header('Vehicle', 90),
        header('Date & Time', 130),
        header('Sync Status', 100),
        header('Last Attempt', 130),
        header('Error', 220),
      ],
      rowValues: rows.map((row) {
        final uid = row.displayUid;
        return [
          cell(SyncStatusController.typeLabel(row.entityType), 100),
          cell(uid == null ? row.recordId : '$uid • ${row.recordId}', 150),
          cell(controller.customerName(row), 120),
          cell(controller.vehicleName(row), 90),
          cell(formatNepaliDateTimeShort(row.date), 130),
          cell(
            SyncStatusController.statusLabel(row),
            100,
            color: SyncStatusController.statusColor(row.status),
          ),
          cell(
            row.lastAttemptAt == null
                ? '-'
                : formatNepaliDateTimeShort(row.lastAttemptAt!),
            130,
          ),
          cell(row.error ?? '-', 220),
        ];
      }).toList(),
    );
  }
}
