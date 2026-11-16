import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../offline/offline_constants.dart';
import '../../../offline/offline_storage.dart';
import '../../../offline/sync/unsynced_records_reader.dart';
import '../../../services/data_cache_service.dart';
import '../../../utils/exceptions/app_exceptions.dart';

/// The dashboard sync pill's three states. Meaning is owned by
/// `HomeController.syncStatusKind`: offline = no connectivity, waiting =
/// unsynced records exist, online = nothing unsynced.
enum SyncStatusKind { offline, waiting, online }

/// Read-only view model of the unsynced records. It never writes to the
/// queue or the records, so opening and closing the view cannot change sync.
class SyncStatusController extends GetxController {
  SyncStatusController({
    required this.kind,
    Stream<List<UnsyncedRecordRow>>? source,
    String Function(String customerId)? customerName,
    String Function(String vehicleId)? vehicleName,
  })  : _source = source,
        _customerName = customerName ?? _cacheCustomerName,
        _vehicleName = vehicleName ?? _cacheVehicleName;

  final SyncStatusKind kind;
  final Stream<List<UnsyncedRecordRow>>? _source;
  final String Function(String) _customerName;
  final String Function(String) _vehicleName;

  final rows = <UnsyncedRecordRow>[].obs;
  final isLoading = true.obs;
  final error = RxnString();

  StreamSubscription<List<UnsyncedRecordRow>>? _subscription;

  static String _cacheCustomerName(String id) =>
      DataCacheService.instance.customers[id]?.name ?? '-';

  static String _cacheVehicleName(String id) =>
      DataCacheService.instance.vehicles[id]?.number ?? '-';

  @override
  void onInit() {
    super.onInit();

    final stream = _source ?? _defaultSource();
    if (stream == null) {
      isLoading.value = false;
      return;
    }

    _subscription = stream.listen(
      (list) {
        rows.assignAll(list);
        error.value = null;
        isLoading.value = false;
      },
      onError: (Object e, StackTrace stack) {
        // Keep the last known rows; a failed read must not look like empty.
        error.value = AppException.messageOf(e);
        isLoading.value = false;
        debugPrint('SyncStatusController read failed: $e\n$stack');
      },
    );
  }

  Stream<List<UnsyncedRecordRow>>? _defaultSource() {
    if (!OfflineStorage.isAvailable) {
      error.value = OfflineStorage.unavailableReason ??
          'Offline storage is not available.';
      return null;
    }
    return UnsyncedRecordsReader(OfflineStorage.instance).watch();
  }

  @override
  void onClose() {
    unawaited(_subscription?.cancel());
    super.onClose();
  }

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
        return 'No unsynced records. New records will appear here until the '
            'connection returns.';
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

  String customerName(UnsyncedRecordRow row) =>
      row.customerId.isEmpty ? '-' : _customerName(row.customerId);

  String vehicleName(UnsyncedRecordRow row) =>
      row.vehicleId.isEmpty ? '-' : _vehicleName(row.vehicleId);

  static String typeLabel(String entityType) {
    switch (SyncEntity.canonical(entityType)) {
      case SyncEntity.activity:
        return 'Activity';
      case SyncEntity.expense:
        return 'Expense';
      case SyncEntity.payment:
        return 'Payment';
      case SyncEntity.customer:
        return 'Customer';
      case SyncEntity.activityLocation:
        return 'Activity location';
      case SyncEntity.expenseLocation:
        return 'Expense location';
      case SyncEntity.user:
        return 'User';
      default:
        return entityType.isEmpty ? '-' : entityType;
    }
  }

  static String statusLabel(UnsyncedRecordRow row) {
    final base = _statusBase(row.status);
    return row.operation == SyncOperation.delete ? '$base (delete)' : base;
  }

  static String _statusBase(String status) {
    switch (status) {
      case QueueStatus.pending:
        return 'Pending';
      case QueueStatus.syncing:
        return 'Syncing';
      case QueueStatus.failed:
        return 'Failed';
      case QueueStatus.conflict:
        return 'Conflict';
      case QueueStatus.blocked:
        return 'Blocked';
      case UnsyncedRecordRow.notQueued:
        return 'Not queued';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case QueueStatus.syncing:
        return Colors.blue.shade700;
      case QueueStatus.failed:
      case QueueStatus.conflict:
      case UnsyncedRecordRow.notQueued:
        return Colors.red.shade700;
      case QueueStatus.blocked:
        return Colors.deepOrange.shade700;
      default:
        return Colors.orange.shade800;
    }
  }
}
