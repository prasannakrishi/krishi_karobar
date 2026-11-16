import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../common/widgets/app_scaffold.dart';
import '../../../common/widgets/appbar.dart';
import '../../../offline/sync/unsynced_records_reader.dart';
import '../../../utils/helper/helpers.dart';
import '../../../utils/theme/widget_themes/custom_decoration.dart';
import '../controller/sync_records_controller.dart';
import '../controller/sync_status_controller.dart';

class SyncRecordsScreen extends StatelessWidget {
  const SyncRecordsScreen({super.key, this.kind = SyncStatusKind.online});

  final SyncStatusKind kind;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<SyncRecordsController>()
        ? Get.find<SyncRecordsController>()
        : Get.put(SyncRecordsController(kind: kind));

    return UAppScaffold(
      transparentBackground: false,
      extendBodyBehindAppBar: false,
      appBar: UAppBar(title: 'Sync Records', showUserName: false,),
      body: Column(
        children: [
          _buildStatusTabs(controller),
          const SizedBox(height: 6),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < 0) {
                  if (controller.currentTabIndex.value < 2) {
                    controller.changeTabIndex(controller.currentTabIndex.value + 1);
                  }
                } else if (velocity > 0) {
                  if (controller.currentTabIndex.value > 0) {
                    controller.changeTabIndex(controller.currentTabIndex.value - 1);
                  }
                }
              },
              child: Obx(() => _buildContent(controller)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs(SyncRecordsController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            controller.sections.length,
            (index) {
              return Expanded(
                child: selectedTab(
                  label: controller.sections[index],
                  isSelected: controller.currentTabIndex.value == index,
                  onTap: () => controller.changeTabIndex(index),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(SyncRecordsController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Obx(() {
        final availableTypes = controller.availableEntityTypes;
        final currentFilter = controller.selectedTypeFilter.value;
        final activeFilter = availableTypes.contains(currentFilter)
            ? currentFilter
            : 'All';

        return Row(
          children: [
            const Icon(Iconsax.filter, size: 18, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            const Text(
              'Type:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activeFilter,
                  isDense: true,
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  items: availableTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (val) => controller.setTypeFilter(val),
                ),
              ),
            ),
            if (controller.currentTabIndex.value == 1 &&
                controller.failedCount > 0) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  await controller.retryFailed();
                  successSnackBar(
                    title: 'Retrying',
                    message: 'Retrying all failed sync records...',
                  );
                },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Retry All', style: TextStyle(fontSize: 11)),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildContent(SyncRecordsController controller) {
    if (controller.isLoading.value && controller.rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final entries = controller.filteredCurrentRows;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          if (controller.error.value != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                controller.error.value!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
          Expanded(
            child: _buildDataTable(controller, entries),
          ),
          _buildDetailsCard(controller, entries),
        ],
      ),
    );
  }

  Widget _buildDataTable(
    SyncRecordsController controller,
    List<UnsyncedRecordRow> entries,
  ) {
    if (entries.isEmpty) {
      String emptyMessage;
      switch (controller.currentTabIndex.value) {
        case 0:
          emptyMessage = 'No pending records waiting to sync.';
          break;
        case 1:
          emptyMessage = 'No failed sync records.';
          break;
        case 2:
          emptyMessage = 'No data conflicts.';
          break;
        default:
          emptyMessage = 'No records found.';
      }
      return Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    Widget headerCell(String title, double width) {
      return uTableCell(
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        width,
      );
    }

    Widget dataCell(String text, double width, {Color? color}) {
      return uTableCell(
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ),
        width,
      );
    }

    return uDataTable(
      columns: [
        headerCell('', 42),
        headerCell('Record Type', 100),
        headerCell('Record UID / ID', 150),
        headerCell('Vehicle', 90),
        headerCell('Sync Status', 100),
        headerCell(
          controller.currentTabIndex.value == 2
              ? 'Conflict Details'
              : 'Failure Reason / Error',
          180,
        ),
        headerCell('Date & Time', 130),
      ],
      selectedIndex: controller.selectedIndex.value,
      onRowSelect: controller.selectIndex,
      rowValues: entries.map((row) {
        final selected = controller.isRowSelected(row.key);
        final uid = row.displayUid;
        final idText = uid == null ? row.recordId : '$uid';
        final errText = row.conflictDetail ?? row.error ?? '-';

        void onTap() {
          if (controller.selectionMode.value) {
            controller.toggleSelection(row.key);
          } else {
            controller.selectRow(row.key);
          }
        }

        void onLongPress() => controller.startMultiSelect(row.key);

        return [
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox(
              width: 42,
              height: 30,
              child: Center(
                child: Checkbox(
                  value: selected,
                  onChanged: controller.selectionMode.value
                      ? (_) => controller.toggleSelection(row.key)
                      : null,
                ),
              ),
            ),
          ),
          dataCell(SyncRecordsController.typeLabel(row.entityType), 100),
          dataCell(idText, 150),
          dataCell(controller.vehicleName(row), 90),
          dataCell(
            SyncRecordsController.statusLabel(row),
            100,
            color: SyncRecordsController.statusColor(row.status),
          ),
          dataCell(errText, 180),
          dataCell(formatNepaliDateTimeShort(row.date), 130),
        ];
      }).toList(),
    );
  }

  Widget _buildDetailsCard(
    SyncRecordsController controller,
    List<UnsyncedRecordRow> entries,
  ) {
    final index = controller.selectedIndex.value;

    if (index == null || index < 0 || index >= entries.length) {
      return const SizedBox.shrink();
    }

    final row = entries[index];
    final isFailedTab = controller.currentTabIndex.value == 1;
    final isConflictTab = controller.currentTabIndex.value == 2;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(top: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Record Details (${SyncRecordsController.typeLabel(row.entityType)})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => controller.selectIndex(null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomDecoration.uTextField(
                    'Record ID',
                    row.recordId,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CustomDecoration.uTextField(
                    'Display UID',
                    row.displayUid ?? '-',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CustomDecoration.uTextField(
                    'Operation',
                    row.operation.toUpperCase(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomDecoration.uTextField(
                    'Customer',
                    controller.customerName(row),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CustomDecoration.uTextField(
                    'Vehicle',
                    controller.vehicleName(row),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CustomDecoration.uTextField(
                    'Date & Time',
                    formatNepaliDateTimeShort(row.date),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (row.error != null && row.error!.isNotEmpty) ...[
              CustomDecoration.uTextField(
                isConflictTab ? 'Conflict Details' : 'Failure Reason',
                row.error!,
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (controller.canManageRecords) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: controller.editSelectedRecord,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: controller.deleteSelectedRecords,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (isFailedTab) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await controller.retryRecord(row);
                      successSnackBar(
                        title: 'Retrying',
                        message: 'Retrying record sync...',
                      );
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry Record'),
                  ),
                ] else if (isConflictTab) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await controller.resolveConflict(row, resolution: 'keep_local');
                      successSnackBar(
                        title: 'Conflict Resolved',
                        message: 'Conflict marked resolved. Retrying sync...',
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Resolve (Keep Local)'),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await controller.triggerSync();
                      successSnackBar(
                        title: 'Syncing',
                        message: 'Triggered synchronization...',
                      );
                    },
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Sync Now'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
