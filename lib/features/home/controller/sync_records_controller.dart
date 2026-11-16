import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../offline/offline_constants.dart';
import '../../../offline/offline_storage.dart';
import '../../../offline/sync/unsynced_records_reader.dart';
import '../../../services/data_cache_service.dart';
import '../../../services/services.dart';
import '../../../utils/exceptions/app_exceptions.dart';
import '../../../utils/helper/helpers.dart';
import 'sync_status_controller.dart';

class SyncRecordsController extends GetxController {
  SyncRecordsController({
    this.kind = SyncStatusKind.online,
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
  final currentTabIndex = 0.obs;
  final selectedTypeFilter = 'All'.obs;
  final selectedIndex = RxnInt();
  final isLoading = true.obs;
  final error = RxnString();

  // Multi-Select state
  final selectedRecordKeys = <String>{}.obs;
  final selectionMode = false.obs;

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
        error.value = AppException.messageOf(e);
        isLoading.value = false;
        debugPrint('SyncRecordsController read failed: $e\n$stack');
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

  List<String> get sections => [
        'Pending ($pendingCount)',
        'Failed ($failedCount)',
        'Conflict ($conflictCount)',
      ];

  /// Classified Rows
  List<UnsyncedRecordRow> get pendingRows {
    return rows.where((r) {
      final isFailed = r.status == QueueStatus.failed;
      final isConflict = r.status == QueueStatus.conflict || r.conflictId != null;
      return !isFailed && !isConflict;
    }).toList();
  }

  List<UnsyncedRecordRow> get failedRows {
    return rows.where((r) {
      final isConflict = r.status == QueueStatus.conflict || r.conflictId != null;
      return r.status == QueueStatus.failed && !isConflict;
    }).toList();
  }

  List<UnsyncedRecordRow> get conflictRows {
    return rows.where((r) {
      return r.status == QueueStatus.conflict || r.conflictId != null;
    }).toList();
  }

  int get pendingCount => pendingRows.length;
  int get failedCount => failedRows.length;
  int get conflictCount => conflictRows.length;

  List<UnsyncedRecordRow> get currentTabRows {
    switch (currentTabIndex.value) {
      case 0:
        return pendingRows;
      case 1:
        return failedRows;
      case 2:
        return conflictRows;
      default:
        return pendingRows;
    }
  }

  List<UnsyncedRecordRow> get filteredCurrentRows {
    final filter = selectedTypeFilter.value;
    if (filter == 'All') return currentTabRows;

    final targetCanonical = SyncEntity.canonical(filter.toLowerCase());
    return currentTabRows.where((r) {
      final canonical = SyncEntity.canonical(r.entityType.toLowerCase());
      return canonical == targetCanonical ||
          typeLabel(r.entityType).toLowerCase() == filter.toLowerCase();
    }).toList();
  }

  List<String> get availableEntityTypes {
    final types = <String>{'All'};
    for (final r in currentTabRows) {
      types.add(typeLabel(r.entityType));
    }
    return types.toList();
  }

  // Admin authorization & selection helpers
  bool get canManageRecords {
    return Authz.can(Permissions.customerEdit) ||
        Authz.can(Permissions.customerDelete) ||
        Authz.can(Permissions.expenseEdit) ||
        Authz.can(Permissions.expenseDelete) ||
        Authz.can(Permissions.userEdit) ||
        Authz.can(Permissions.vehicleEdit);
  }

  bool isRowSelected(String key) => selectedRecordKeys.contains(key);
  bool get hasSelection => selectedRecordKeys.isNotEmpty;
  bool get isModelAllSelected =>
      filteredCurrentRows.isNotEmpty &&
      selectedRecordKeys.length == filteredCurrentRows.length;
  bool get isPartiallySelected =>
      selectedRecordKeys.isNotEmpty &&
      selectedRecordKeys.length < filteredCurrentRows.length;

  void toggleSelection(String key) {
    if (selectedRecordKeys.contains(key)) {
      selectedRecordKeys.remove(key);
    } else {
      selectedRecordKeys.add(key);
    }
    if (selectedRecordKeys.isEmpty) {
      selectionMode.value = false;
    }
  }

  void selectRow(String key) {
    if (selectionMode.value) {
      toggleSelection(key);
      return;
    }
    if (selectedRecordKeys.contains(key) && selectedRecordKeys.length == 1) {
      selectedRecordKeys.clear();
      return;
    }
    selectedRecordKeys.assignAll([key]);
  }

  void startMultiSelect(String key) {
    selectionMode.value = true;
    selectedRecordKeys.add(key);
  }

  void toggleSelectAll() {
    if (isModelAllSelected) {
      selectedRecordKeys.clear();
      selectionMode.value = false;
    } else {
      selectedRecordKeys.assignAll(filteredCurrentRows.map((r) => r.key));
      selectionMode.value = true;
    }
  }

  void clearSelection() {
    selectedRecordKeys.clear();
    selectionMode.value = false;
  }

  UnsyncedRecordRow? get selectedSingleRecord {
    if (selectedRecordKeys.length != 1) return null;
    final key = selectedRecordKeys.first;
    return filteredCurrentRows.firstWhereOrNull((r) => r.key == key);
  }

  void changeTabIndex(int index) {
    if (currentTabIndex.value != index) {
      currentTabIndex.value = index;
      selectedIndex.value = null;
      clearSelection();
    }
  }

  void setTypeFilter(String? type) {
    if (type != null && selectedTypeFilter.value != type) {
      selectedTypeFilter.value = type;
      selectedIndex.value = null;
      clearSelection();
    }
  }

  void selectIndex(int? index) {
    selectedIndex.value = index;
  }

  Future<void> triggerSync() async {
    if (OfflineStorage.isAvailable) {
      await OfflineStorage.instance.syncNow(isManual: true);
    }
  }

  Future<void> retryFailed() async {
    if (OfflineStorage.isAvailable) {
      await OfflineStorage.instance.retryFailedSync();
    }
  }

  Future<void> retryRecord(UnsyncedRecordRow row) async {
    if (!OfflineStorage.isAvailable) return;
    try {
      final info = await OfflineStorage.instance.workspaces.current();
      if (info == null) return;
      await OfflineStorage.instance.queue.resetToPending(
        info.workspaceId,
        row.entityType,
        row.recordId,
        resetAttempts: true,
      );
      await OfflineStorage.instance.syncNow(isManual: true);
    } catch (e) {
      debugPrint('SyncRecordsController retryRecord error: $e');
    }
  }

  Future<void> resolveConflict(UnsyncedRecordRow row, {String resolution = 'keep_local'}) async {
    if (!OfflineStorage.isAvailable) return;
    try {
      if (row.conflictId != null) {
        await OfflineStorage.instance.resolveConflict(
          row.conflictId!,
          resolution: resolution,
        );
      } else {
        final info = await OfflineStorage.instance.workspaces.current();
        if (info == null) return;
        await OfflineStorage.instance.queue.resetToPending(
          info.workspaceId,
          row.entityType,
          row.recordId,
          resetAttempts: true,
        );
        await OfflineStorage.instance.syncNow(isManual: true);
      }
    } catch (e) {
      debugPrint('SyncRecordsController resolveConflict error: $e');
    }
  }

  Future<void> editSelectedRecord() async {
    final row = selectedSingleRecord;
    if (row == null) return;
    if (!canManageRecords) {
      error.value = 'Permission denied to edit records.';
      errorSnackBar(title: 'Access Denied', message: 'You do not have permission to edit records.');
      return;
    }

    await Get.dialog<void>(
      _RecordEditDialog(row: row, controller: this),
    );
  }

  Future<void> saveEditedRecord(UnsyncedRecordRow row, Map<String, dynamic> updatedData) async {
    try {
      if (!OfflineStorage.isAvailable) return;

      final info = await OfflineStorage.instance.workspaces.current();
      if (info == null) return;

      final record = await OfflineStorage.instance.localRecords.getRecord(
        info.scope,
        row.entityType,
        row.recordId,
      );

      if (record == null) {
        throw const DataValidationException(code: 'not-found', details: 'Local record not found.');
      }

      final mergedData = {
        ...record.data,
        ...updatedData,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

      await OfflineStorage.saveLocalOrThrow(
        entityType: row.entityType,
        recordId: row.recordId,
        data: mergedData,
        isNew: record.isNew,
      );

      clearSelection();
      successSnackBar(title: 'Success', message: 'Record updated successfully.');
    } catch (e) {
      error.value = AppException.messageOf(e);
      errorSnackBar(title: 'Error', message: AppException.messageOf(e));
    }
  }

  Future<void> deleteSelectedRecords() async {
    if (selectedRecordKeys.isEmpty) return;
    if (!canManageRecords) {
      error.value = 'Permission denied to delete records.';
      errorSnackBar(title: 'Access Denied', message: 'You do not have permission to delete records.');
      return;
    }

    final count = selectedRecordKeys.length;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Delete Record${count > 1 ? 's' : ''}'),
        content: Text('Are you sure you want to delete $count selected record${count > 1 ? 's' : ''}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    isLoading.value = true;
    try {
      if (!OfflineStorage.isAvailable) return;

      final info = await OfflineStorage.instance.workspaces.current();
      if (info == null) return;

      for (final key in selectedRecordKeys.toList()) {
        final row = rows.firstWhereOrNull((r) => r.key == key);
        if (row == null) continue;

        final record = await OfflineStorage.instance.localRecords.getRecord(
          info.scope,
          row.entityType,
          row.recordId,
        );

        if (record != null && record.isNew) {
          await OfflineStorage.instance.queue.remove(info.scope.workspaceId, row.entityType, row.recordId);
          await OfflineStorage.instance.records.delete(info.scope.workspaceId, row.entityType, row.recordId);
        } else if (record != null) {
          await OfflineStorage.instance.localRecords.markDeleted(
            info.scope,
            entityType: row.entityType,
            recordId: row.recordId,
          );
        }
      }

      clearSelection();
      successSnackBar(title: 'Success', message: '$count record${count > 1 ? 's' : ''} deleted successfully.');
    } catch (e) {
      error.value = AppException.messageOf(e);
      errorSnackBar(title: 'Error', message: AppException.messageOf(e));
    } finally {
      isLoading.value = false;
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
        return 'Activity Location';
      case SyncEntity.expenseLocation:
        return 'Expense Location';
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

class _RecordEditDialog extends StatefulWidget {
  const _RecordEditDialog({required this.row, required this.controller});

  final UnsyncedRecordRow row;
  final SyncRecordsController controller;

  @override
  State<_RecordEditDialog> createState() => _RecordEditDialogState();
}

class _RecordEditDialogState extends State<_RecordEditDialog> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Record (${SyncRecordsController.typeLabel(widget.row.entityType)})'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record ID: ${widget.row.recordId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Update Notes / Description / Data',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
          onPressed: () async {
            final text = _noteController.text.trim();
            if (text.isNotEmpty) {
              await widget.controller.saveEditedRecord(
                widget.row,
                {'note': text, 'description': text},
              );
            }
            Get.back();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
