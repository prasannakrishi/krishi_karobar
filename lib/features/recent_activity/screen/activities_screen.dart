import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/features/navigarion/controller/navigation_controller.dart';
import 'package:krishi_karobar/services/data_cache_service.dart';
import 'package:krishi_karobar/utils/helper/helper_functions.dart';
import 'package:krishi_karobar/features/recent_activity/screen/widgets/filter_header.dart';
import '../../../common/widgets/appbar.dart';
import '../../../utils/constants/enums.dart';
import '../controllers/activity_controller.dart';
import 'widgets/details_card_form.dart';
import 'widgets/summary_footer.dart';


class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Controller initialization
    final controller = Get.put(ActivityController());
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: UAppBar(
        title: 'Activities',
      ),
      body: Column(

        children: [

          // Status Tabs (Paid, Due, Partial)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2),
            child: Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(controller.sections.length, (index) {
                return Expanded(
                  child: UHelperFunctions.selectedTab(
                    label: controller.sections[index],
                    isSelected: controller.currentPageIndex.value == index,
                    onTap: () => controller.changePageIndex(index),
                  ),
                );
              }),
            )),
          ),
          
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                final navController = Get.find<NavigationController>();
                
                if (velocity < 0) { // Left Swipe
                  if (controller.currentPageIndex.value < 2) {
                    controller.changePageIndex(controller.currentPageIndex.value + 1);
                  } else {
                    // Go to User/Settings Screen
                    navController.onTabSelected(3);
                  }
                } else if (velocity > 0) { // Right Swipe
                  if (controller.currentPageIndex.value > 0) {
                    controller.changePageIndex(controller.currentPageIndex.value - 1);
                  } else {
                    // Go to Monitor Screen
                    navController.onTabSelected(1);
                  }
                }
              },
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                final section = [
                  PaymentStatus.payed,
                  PaymentStatus.due,
                  PaymentStatus.partial,
                ][controller.currentPageIndex.value];
                
                final entries = controller.activitiesForSection(section);
                
                final totalSeconds = controller.totalSecondsFor(controller.activities);
                final totalAmount = controller.totalAmountFor(controller.activities);
                final totalPaid = controller.totalPaidFor(controller.activities);
                final totalDue = controller.totalDueFor(controller.activities);

                return Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Expanded(
                        child: Stack(
                          children:[
                            UHelperFunctions.UDataTable(
                              columns: [
                                  _buildCell(FilterHeader(title: 'ActivityId', isActive: controller.selectedVehicleGuids.isNotEmpty || controller.selectedServiceFilter.value != 'All', onTap: controller.showAIdFilters), 80),
                                  _buildCell(FilterHeader(title: 'Customer', isActive: controller.nameSearchQuery.value.isNotEmpty, onTap: controller.showNameSearch), 90),
                                  _buildCell(const Center(child: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold))), 70),
                                  _buildCell(const Align(alignment: Alignment.center, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))), 60),
                                  _buildCell(FilterHeader(title: 'Created On', isActive: true, onTap: controller.showDateFilter), 120),
                              ],
                              rowValues: entries.map((e) => [
                                _buildCell(Text(e.uid), 80),
                                _buildCell(Text(DataCacheService.instance.getCustomerName(e.customer)), 150),
                                _buildCell(Center(child: Text(e.duration)), 70),
                                _buildCell(Align(alignment: Alignment.centerRight, child: Text('रु ${e.amount}')), 60),
                                _buildCell(Text(controller.formatDate(e.createdAt)), 100),
                              ]).toList(),
                              selectedIndex: controller.selectedIndex.value,
                              onRowSelect: (index) => controller.selectIndex(index),
                            ),
                            if (entries.isEmpty)
                              const Center(
                                child: Text('No records found for this section'),
                              ),
                          ],
                        ),
                      ),

                      if (controller.selectedIndex.value != null &&
                          controller.selectedIndex.value! >= 0 &&
                          controller.selectedIndex.value! < entries.length) ...[
                        const SizedBox(height: 12),
                        DetailsCardForm(
                          entry: entries[controller.selectedIndex.value!],
                          controller: controller,
                        ),
                      ],

                      const SizedBox(height: 12),
                      SummaryFooter(
                        totalSeconds: totalSeconds,
                        totalAmount: totalAmount,
                        totalPaid: totalPaid,
                        totalDue: totalDue,
                        controller: controller,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(Widget child, double width) {
    return SizedBox(
      width: width,
      child: MarqueeWidget(child: child)
    );
  }
}
