import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/appbar.dart';
import '../../../common/widgets/app_scaffold.dart';
import '../../../models/models.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/helper/helper_widgets.dart';
import 'package:krishi_karobar/features/controllers.dart';
import 'widgets/details_card_form.dart';
import 'widgets/filter_header.dart';
import 'widgets/summary_footer.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ActivityController());

    return UAppScaffold(
      transparentBackground: true,
      extendBodyBehindAppBar: false,
      appBar: UAppBar(title: 'Activities'),
      body: Column(
        children: [
          _buildStatusTabs(controller),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                final navigationController = Get.find<NavigationController>();

                if (velocity < 0) {
                  if (controller.currentPageIndex.value < 2) {
                    controller.changePageIndex(
                      controller.currentPageIndex.value + 1,
                    );
                  } else {
                    navigationController.onTabSelected(3);
                  }
                } else if (velocity > 0) {
                  if (controller.currentPageIndex.value > 0) {
                    controller.changePageIndex(
                      controller.currentPageIndex.value - 1,
                    );
                  } else {
                    navigationController.onTabSelected(1);
                  }
                }
              },
              child: Obx(
                    () => _buildContent(controller),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs(ActivityController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 2,
      ),
      child: Obx(
            () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            controller.sections.length,
                (index) {
              return Expanded(
                child: selectedTab(
                  label: controller.sections[index],
                  isSelected:
                  controller.currentPageIndex.value == index,
                  onTap: () =>controller.changePageIndex(index),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ActivityController controller) {
    if (controller.isLoading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    final section = _currentSection(controller);
    final filterEntries = controller.filteredActivities();
    final sectionEntries = controller.activitiesForSection(section);

    final totalSeconds = controller.totalSecondsFor(filterEntries);
    final totalAmount = controller.totalAmountFor(filterEntries);
    final totalPaid = controller.totalPaidFor(filterEntries);
    final totalDue = controller.totalDueFor(filterEntries);
/* allEntries wise summury
    final totalSeconds = controller.totalSecondsFor(sectionEntries);
    final totalAmount = controller.totalAmountFor(sectionEntries);
    final totalPaid = controller.totalPaidFor(sectionEntries);
    final totalDue = controller.totalDueFor(sectionEntries);
*/

    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Expanded(
            child: _buildActivityTable(
              controller,
              sectionEntries,
            ),
          ),
          _buildDetails(
            controller,
            sectionEntries,
          ),
          const SizedBox(height: 4),
          SummaryFooter(
            totalSeconds: totalSeconds,
            totalAmount: totalAmount,
            totalPaid: totalPaid,
            totalDue: totalDue,
          ),
        ],
      ),
    );
  }

  PaymentStatus _currentSection(ActivityController controller) {
    switch (controller.currentPageIndex.value) {
      case 1:
        return PaymentStatus.due;
      case 2:
        return PaymentStatus.partial;
      default:
        return PaymentStatus.payed;
    }
  }

  void _showContextMenu(BuildContext context,ActivityController controller,ActivityModel activity,TapUpDetails? details) {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final position = details != null
        ? RelativeRect.fromRect(
            details.globalPosition & const Size(40, 40),
            Offset.zero & overlay.size,
          )
        : RelativeRect.fromLTRB(
            overlay.size.width * 0.5,
            overlay.size.height * 0.4,
            overlay.size.width * 0.5,
            overlay.size.height * 0.4,
          );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text('Edit Activity'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Delete Activity', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        controller.showEditActivityDialog(activity);
      } else if (value == 'delete') {
        controller.confirmDeleteActivity(activity);
      }
    });
  }

  Widget _buildActivityTable(ActivityController controller, List<ActivityModel> entries) {
    return Builder(
      builder: (context) {
        return Stack(
          children: [
            uDataTable(
              columns: [
                _buildCell(
                  FilterHeader(
                    title: 'Activity ID',
                    isActive:
                        controller.selectedVehicleIds.isNotEmpty ||
                            controller.selectedServiceFilter.value != 'All',
                    onTap: controller.showAIdFilters,
                  ),
                  100,
                ),
                _buildCell(
                  FilterHeader(
                    title: 'Customer',
                    isActive: controller.nameSearchQuery.value.isNotEmpty,
                    onTap: controller.showNameSearch,
                  ),
                  120,
                ),
                _buildCell(
                  const Center(
                    child: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  80,
                ),
                _buildCell(
                  const Align(
                    alignment: Alignment.center,
                    child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  80,
                ),
                _buildCell(
                  FilterHeader(
                    title: 'Created On',
                    isActive: controller.selectedFilter.value != 'All',
                    onTap: controller.showDateFilter,
                  ),
                  130,
                ),
                _buildCell(
                  const Center(
                    child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  80,
                ),
              ],
              rowValues: entries.map(
                (activity) {
                  return [
                    _buildCell(
                      Text(activity.uId),
                      100,
                    ),
                    _buildCell(
                      Text(
                        controller.customerName(
                          activity.customerId,
                        ),
                      ),
                      120,
                    ),
                    _buildCell(
                      Center(
                        child: Text(
                          controller.secondsToHHMMSS(
                            activity.duration,
                          ),
                        ),
                      ),
                      80,
                    ),
                    _buildCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'रु ${activity.amount.toStringAsFixed(0)}',
                        ),
                      ),
                      80,
                    ),
                    _buildCell(
                      Text(
                        controller.formatDate(
                          activity.createdAt,
                        ),
                      ),
                      130,
                    ),
                    _buildCell(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Edit',
                            onPressed: () => controller.showEditActivityDialog(activity),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete',
                            onPressed: () => controller.confirmDeleteActivity(activity),
                          ),
                        ],
                      ),
                      80,
                    ),
                  ];
                },
              ).toList(),
              selectedIndex: controller.selectedIndex.value,
              onRowSelect: controller.selectIndex,
              onRowLongPress: (index) {
                if (index >= 0 && index < entries.length) {
                  _showContextMenu(context, controller, entries[index], null);
                }
              },
            ),
            if (entries.isEmpty)
              const Center(
                child: Text(
                  'No records found for this section',
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDetails(ActivityController controller,List<ActivityModel> entries) {
    final index = controller.selectedIndex.value;

    if (index == null ||
        index < 0 ||
        index >= entries.length) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 5),
        DetailsCardForm(
          key: ValueKey(entries[index].id),
          entry: entries[index],
          controller: controller,
        ),
      ],
    );
  }

  Widget _buildCell(
      Widget child,
      double width,
      ) {
    return SizedBox(
      width: width,
      height: 32,
      child: Center(
        child: MarqueeWidget(
          child: child,
        ),
      ),
    );
  }
}