import 'package:flutter/material.dart';

import 'sync_records_controller.dart';

/// The dashboard sync pill's three states.
enum SyncStatusKind { offline, waiting, online }

/// Controller for Sync Records screen and status status pill monitoring.
class SyncStatusController extends SyncRecordsController {
  SyncStatusController({
    super.kind = SyncStatusKind.online,
    super.source,
    super.customerName,
    super.vehicleName,
  });

  String get title {
    switch (kind) {
      case SyncStatusKind.offline:
        return 'Offline';
      case SyncStatusKind.waiting:
        return 'Waiting to sync';
      case SyncStatusKind.online:
        return 'Online';
    }
  }

  String get emptyMessage {
    switch (kind) {
      case SyncStatusKind.offline:
        return 'No unsynced records. New records will appear here until the connection returns.';
      case SyncStatusKind.waiting:
      case SyncStatusKind.online:
        return 'All records are synced.';
    }
  }

  Color get color {
    switch (kind) {
      case SyncStatusKind.offline:
        return Colors.amber.shade800;
      case SyncStatusKind.waiting:
        return Colors.orange.shade800;
      case SyncStatusKind.online:
        return Colors.green;
    }
  }
}
