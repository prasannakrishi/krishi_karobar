import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/sync_status_controller.dart';
import '../screen/sync_records_screen.dart';

/// Legacy entry point for sync status inspection, now navigating to full-screen
/// [SyncRecordsScreen].
class SyncStatusDialog extends StatelessWidget {
  const SyncStatusDialog({super.key, this.onSyncNow});

  final Future<void> Function()? onSyncNow;

  static Future<void> show(
    SyncStatusKind kind, {
    Future<void> Function()? onSyncNow,
  }) async {
    if (Get.isRegistered<SyncStatusController>()) {
      Get.delete<SyncStatusController>(force: true);
    }
    Get.put(SyncStatusController(kind: kind));
    try {
      await Get.to<void>(() => SyncRecordsScreen(kind: kind));
    } finally {
      if (Get.isRegistered<SyncStatusController>()) {
        Get.delete<SyncStatusController>(force: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<SyncStatusController>()
        ? Get.find<SyncStatusController>()
        : Get.put(SyncStatusController());
    return SyncRecordsScreen(kind: controller.kind);
  }
}
