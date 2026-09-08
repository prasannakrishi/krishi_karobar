import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/appbar.dart';
import '../../../common/widgets/app_scaffold.dart';
import '../../../models/models.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../../navigarion/controller/navigation_controller.dart';
import '../controllers/activity_controller.dart';
import 'widgets/details_card_form.dart';
import 'widgets/filter_header.dart';
import 'widgets/summary_footer.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ActivityController());

    return UAppScaffold(
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
                final navigationController =
                Get.find<NavigationController>();

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
                  onTap: () =>
                      controller.changePageIndex(index),
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final section = _currentSection(controller);
    final entries =
    controller.activitiesForSection(section);

    final totalSeconds =
    controller.totalSecondsFor(entries);
    final totalAmount =
    controller.totalAmountFor(entries);
    final totalPaid =
    controller.totalPaidFor(entries);
    final totalDue =
    controller.totalDueFor(entries);

    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Expanded(
            child: _buildActivityTable(
              controller,
              entries,
            ),
          ),
          _buildDetails(
            controller,
            entries,
          ),
          const SizedBox(height: 12),
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

  PaymentStatus _currentSection(
      ActivityController controller,
      ) {
    switch (controller.currentPageIndex.value) {
      case 1:
        return PaymentStatus.due;
      case 2:
        return PaymentStatus.partial;
      default:
        return PaymentStatus.payed;
    }
  }

  Widget _buildActivityTable(
      ActivityController controller,
      List<ActivityModel> entries,
      ) {
    return Stack(
      children: [
        UDataTable(
          columns: [
            _buildCell(
              FilterHeader(
                title: 'Activity ID',
                isActive:
                controller.selectedVehicleIds.isNotEmpty ||
                    controller.selectedServiceFilter.value !=
                        'All',
                onTap: controller.showAIdFilters,
              ),
              100,
            ),
            _buildCell(
              FilterHeader(
                title: 'Customer',
                isActive:
                controller.nameSearchQuery.value.isNotEmpty,
                onTap: controller.showNameSearch,
              ),
              120,
            ),
            _buildCell(
              const Center(
                child: Text(
                  'Duration',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              80,
            ),
            _buildCell(
              const Align(
                alignment: Alignment.center,
                child: Text(
                  'Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              80,
            ),
            _buildCell(
              FilterHeader(
                title: 'Created On',
                isActive:
                controller.selectedFilter.value != 'All',
                onTap: controller.showDateFilter,
              ),
              130,
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
                      'रु ${activity.amount.toStringAsFixed(2)}',
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
              ];
            },
          ).toList(),
          selectedIndex:
          controller.selectedIndex.value,
          onRowSelect: controller.selectIndex,
        ),
        if (entries.isEmpty)
          const Center(
            child: Text(
              'No records found for this section',
            ),
          ),
      ],
    );
  }

  Widget _buildDetails(
      ActivityController controller,
      List<ActivityModel> entries,
      ) {
    final index = controller.selectedIndex.value;

    if (index == null ||
        index < 0 ||
        index >= entries.length) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 12),
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
      child: MarqueeWidget(
        child: child,
      ),
    );
  }
}