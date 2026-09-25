import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/appbar.dart';
import '../../../common/widgets/app_scaffold.dart';
import '../../../models/models.dart';
import '../../../services/authorization_service.dart';
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
      appBar: UAppBar(
        title: 'Activities',
        showUserName: true,
        actions: [
          Obx(() {
            final tabIndex = controller.currentPageIndex.value;
            if ((tabIndex == 0 || tabIndex == 1) && Authz.can(Permissions.activityCreate)) {
              return IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: controller.showAddActivityDialog,
              );
            }
            if (tabIndex == 2 && Authz.can(Permissions.expenseCreate)) {
              return IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: controller.showAddExpenseDialog,
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
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
                  onTap: () => controller.changePageIndex(index),
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

    final isExpensesTab = controller.currentPageIndex.value == 2;

    if (isExpensesTab) {
      final expenses = controller.expensesList;
      return Padding(
        padding: const EdgeInsets.all(1),
        child: Column(
          children: [
            const SizedBox(height: 4),
            Expanded(
              child: _buildExpenseTable(controller, expenses),
            ),
            const SizedBox(height: 12),
            _buildExpenseSummary(controller, expenses),
          ],
        ),
      );
    }

    final section = _currentSection(controller);
    final filterEntries = controller.filteredActivities();
    final sectionEntries = controller.activitiesForSection(section);

    final totalSeconds = controller.totalSecondsFor(filterEntries);
    final totalAmount = controller.totalAmountFor(filterEntries);
    final totalPaid = controller.totalPaidFor(filterEntries);
    final totalDue = controller.totalDueFor(filterEntries);

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

  Widget _buildExpenseTable(ActivityController controller, List<ExpenseModel> expenses) {
    return Stack(
      children: [
        uDataTable(
          columns: [
            _buildCell(const Text('Expense ID', style: TextStyle(fontWeight: FontWeight.bold)), 100),
            _buildCell(const Text('Expense Name', style: TextStyle(fontWeight: FontWeight.bold)), 130),
            _buildCell(
              FilterHeader(
                title: 'Type',
                isActive: controller.selectedExpenseTypeFilter.value != 'All',
                onTap: controller.showExpenseTypeFilter,
              ),
              110,
            ),
            _buildCell(const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)), 80),
            _buildCell(const Text('Paid', style: TextStyle(fontWeight: FontWeight.bold)), 70),
            _buildCell(const Text('Due', style: TextStyle(fontWeight: FontWeight.bold)), 70),
            _buildCell(
              FilterHeader(
                title: 'Created At',
                isActive: controller.selectedFilter.value != 'All',
                onTap: controller.showDateFilter,
              ),
              130,
            ),
            _buildCell(const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)), 80),
          ],
          rowValues: expenses.map((expense) {
            final canEdit = Authz.can(Permissions.expenseEdit);
            final canDelete = Authz.can(Permissions.expenseDelete);
            final expenseName = expense.description?.isNotEmpty == true
                ? '${expense.categoryName} - ${expense.description}'
                : expense.categoryName;

            return [
              _buildCell(Text(expense.uId), 100),
              _buildCell(Text(expenseName, maxLines: 1, overflow: TextOverflow.ellipsis), 130),
              _buildCell(Text(expense.expenseType), 110),
              _buildCell(Align(alignment: Alignment.centerRight, child: Text('रु ${expense.amount}')), 80),
              _buildCell(Align(alignment: Alignment.centerRight, child: Text('रु ${expense.paidAmount}')), 70),
              _buildCell(Align(alignment: Alignment.centerRight, child: Text('रु ${expense.dueAmount}', style: TextStyle(color: expense.dueAmount > 0 ? Colors.red : null))), 70),
              _buildCell(Text(controller.formatDate(expense.createdAt)), 130),
              _buildCell(
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (canEdit)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Edit',
                        onPressed: () => controller.showEditExpenseDialog(expense),
                      ),
                    if (canEdit && canDelete) const SizedBox(width: 6),
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Delete',
                        onPressed: () => controller.confirmDeleteExpense(expense),
                      ),
                  ],
                ),
                80,
              ),
            ];
          }).toList(),
        ),
        if (expenses.isEmpty)
          const Center(
            child: Text('No expense records found'),
          ),
      ],
    );
  }

  Widget _buildExpenseSummary(ActivityController controller, List<ExpenseModel> expenses) {
    final totalExp = expenses.fold(0, (sum, e) => sum + e.amount);
    final totalPaid = expenses.fold(0, (sum, e) => sum + e.paidAmount);
    final totalDue = expenses.fold(0, (sum, e) => sum + e.dueAmount);
    final count = expenses.length;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          children: [
            const Row(
              children: [
                Expanded(child: Text('Expenses', style: TextStyle(color: Colors.brown, fontSize: 15, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Paid', textAlign: TextAlign.center, style: TextStyle(color: Colors.brown, fontSize: 15, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Due', textAlign: TextAlign.center, style: TextStyle(color: Colors.brown, fontSize: 15, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Count', textAlign: TextAlign.right, style: TextStyle(color: Colors.brown, fontSize: 15, fontWeight: FontWeight.w600))),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            Row(
              children: [
                Expanded(child: Text('रु $totalExp', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                Expanded(child: Text('रु $totalPaid', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green))),
                Expanded(child: Text('रु $totalDue', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red))),
                Expanded(child: Text('$count', textAlign: TextAlign.right, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
          ],
        ),
      ),
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

  Widget _buildCell(Widget child,double width) {
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
