import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/appbar.dart';
import '../../../common/widgets/app_scaffold.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/helper/helpers.dart';
import '../../../utils/theme/widget_themes/custom_decoration.dart';
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
                  }
                  else {
                    navigationController.onTabSelected(3);
                  }
                }
                else if (velocity > 0) {
                  if (controller.currentPageIndex.value > 0) {
                    controller.changePageIndex(
                      controller.currentPageIndex.value - 1,
                    );
                  }
                  else {
                    navigationController.onTabSelected(1);
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
            Expanded(child: _buildExpenseTable(controller, expenses)),
            _buildExpenseDetails(controller, expenses),
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
    final totalDiscount = controller.totalDiscountFor(filterEntries);
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
            totalDiscount: totalDiscount,
            totalDue: totalDue,
          ),
        ],
      ),
    );
  }

  ActivityState _currentSection(ActivityController controller) {
    switch (controller.currentPageIndex.value) {
      case 0:
        return ActivityState.payed;
      case 1:
        return ActivityState.due;
      case 2:
        return ActivityState.expences;
      default:
        return ActivityState.due;
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
                    alignment: Alignment.centerRight,
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
              ],
              rowValues: entries.map(
                (activity) {
                  return [
                    _buildCell(
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(activity.uId),
                      ),
                      100,
                    ),
                    _buildCell(
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(controller.customerName(activity.customerId,))
                      ),
                      120,
                    ),
                    _buildCell(
                    Align(
                      alignment: Alignment.center,
                      child: Text(secondsToHHMMSS(activity.duration)),
                    ),
                    80,
                    ),
                    _buildCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('रु ${activity.amount.toStringAsFixed(0)}'),
                      ),
                      80,
                    ),
                    _buildCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child:Text(controller.formatDate(activity.createdAt))
                      ),
                      130,
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
    return Builder(
      builder: (context) {
        return Stack(
          children: [
            uDataTable(
              columns: [
                _buildCell(Center(child: const Text('Exp. ID', style: TextStyle(fontWeight: FontWeight.bold))), 60),
                _buildCell(Center(child: const Text('Expense Name', style: TextStyle(fontWeight: FontWeight.bold))), 150),
                _buildCell(
                  Center(
                    child: FilterHeader(
                      title: 'Type',
                      isActive: controller.selectedExpenseTypeFilter.value != 'All',
                      onTap: controller.showExpenseTypeFilter,
                    ),
                  ),
                  70,
                ),
                _buildCell(Center(child: const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))), 70),
                _buildCell(Center(child: const Text('Paid', style: TextStyle(fontWeight: FontWeight.bold))), 70),
                _buildCell(Center(child: const Text('Due', style: TextStyle(fontWeight: FontWeight.bold))), 70),
                _buildCell(
                  Center(
                    child: FilterHeader(
                      title: 'Created At',
                      isActive: controller.selectedFilter.value != 'All',
                      onTap: controller.showDateFilter,
                    ),
                  ),
                  130,
                ),
              ],
              rowValues: expenses.map((expense) {
                final expenseName = expense.description?.isNotEmpty == true
                    ? '${expense.categoryName} - ${expense.description}'
                    : expense.categoryName;

                return [
                  _buildCell(Center(child: Text(expense.uId, textAlign: TextAlign.center)), 60),
                  _buildCell(Center(child: Text(expenseName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)), 180),
                  _buildCell(Center(child: Text(expense.expenseType, textAlign: TextAlign.center)), 70),
                  _buildCell(Center(child: Text('रु ${expense.amount}', textAlign: TextAlign.center)), 70),
                  _buildCell(Center(child: Text('रु ${expense.paidAmount}', textAlign: TextAlign.center)), 70),
                  _buildCell(Center(child: Text('रु ${expense.dueAmount}', textAlign: TextAlign.center, style: TextStyle(color: expense.dueAmount > 0 ? Colors.red : null))), 70),
                  _buildCell(Center(child: Text(controller.formatDate(expense.createdAt), textAlign: TextAlign.center)), 130),
                ];
              }).toList(),
              selectedIndex: controller.selectedIndex.value,
              onRowSelect: controller.selectIndex,
              onRowLongPress: (index) {
                if (index >= 0 && index < expenses.length) {
                  _showExpenseContextMenu(context, controller, expenses[index], null);
                }
              },
            ),
            if (expenses.isEmpty)
              const Center(
                child: Text('No expense records found'),
              ),
          ],
        );
      },
    );
  }

  void _showExpenseContextMenu(BuildContext context, ActivityController controller, ExpenseModel expense, TapUpDetails? details) {
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
              Text('Edit Expense'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Delete Expense', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        controller.showEditExpenseDialog(expense);
      } else if (value == 'delete') {
        controller.confirmDeleteExpense(expense);
      }
    });
  }

  Widget _buildExpenseDetails(ActivityController controller, List<ExpenseModel> expenses) {
    final index = controller.selectedIndex.value;

    if (index == null || index < 0 || index >= expenses.length) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 5),
        ExpenseDetailsCardForm(
          key: ValueKey(expenses[index].id),
          expense: expenses[index],
          controller: controller,
        ),
      ],
    );
  }

  Widget _buildExpenseSummary(ActivityController controller, List<ExpenseModel> expenses) {
    final totalExp = expenses.fold(0, (sum, e) => sum + e.amount);
    final totalPaid = expenses.fold(0, (sum, e) => sum + e.paidAmount);
    final totalDue = expenses.fold(0, (sum, e) => sum + e.dueAmount);
    final count = expenses.length;

    return UnifiedSummaryCard(
      backgroundColor: const Color(0xFFFFF3E0),
      items: [
        SummaryItem(
          label: 'Expenses',
          value: 'रु $totalExp',
          alignment: TextAlign.left,
          textColor: Colors.brown,
        ),
        SummaryItem(
          label: 'Paid',
          value: 'रु $totalPaid',
          alignment: TextAlign.center,
          textColor: Colors.green,
        ),
        SummaryItem(
          label: 'Due',
          value: 'रु $totalDue',
          alignment: TextAlign.center,
          textColor: Colors.red,
        ),
        SummaryItem(
          label: 'Count',
          value: '$count',
          alignment: TextAlign.right,
          textColor: Colors.brown,
        ),
      ],
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
      height: 30,
      child: MarqueeWidget(
        child: child,
      ),
    );
  }
}

class ExpenseDetailsCardForm extends StatefulWidget {
  const ExpenseDetailsCardForm({
    super.key,
    required this.expense,
    required this.controller,
  });

  final ExpenseModel expense;
  final ActivityController controller;

  @override
  State<ExpenseDetailsCardForm> createState() => _ExpenseDetailsCardFormState();
}

class _ExpenseDetailsCardFormState extends State<ExpenseDetailsCardForm> {
  String? _expenseLocationText;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _fetchExpenseLocation();
  }

  @override
  void didUpdateWidget(covariant ExpenseDetailsCardForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expense.id != widget.expense.id) {
      _fetchExpenseLocation();
    }
  }

  void _fetchExpenseLocation() async {
    try {
      final data = await FirebaseService().getRecordById('expense_locations', widget.expense.id);
      if (data != null && data['location'] != null && data['location'] is Map) {
        final locMap = Map<String, dynamic>.from(data['location'] as Map);
        _lat = toDouble(locMap['latitude']);
        _lng = toDouble(locMap['longitude']);
        final address = await LocationService.instance.getAddressFromCoordinates(_lat!, _lng!);
        if (mounted) {
          setState(() {
            _expenseLocationText = address;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _expenseLocationText = 'Location not captured';
          });
        }
      }
    } catch (e) {
      debugPrint('ExpenseDetailsCardForm location fetch error: $e');
      if (mounted) {
        setState(() {
          _expenseLocationText = 'Location not captured';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Authz.canViewActivityGps();
    final locationDisplay = _expenseLocationText ?? 'Loading location...';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color.fromARGB(255, 255, 243, 224),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: CustomDecoration.uTextField('Expense ID', widget.expense.uId),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: CustomDecoration.uTextField('Type', widget.expense.expenseType),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: CustomDecoration.uTextField('Category', widget.expense.categoryName),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomDecoration.uTextField('Amount', 'रु ${widget.expense.amount}'),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: CustomDecoration.uTextField('Paid', 'रु ${widget.expense.paidAmount}'),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: CustomDecoration.uTextField('Due', 'रु ${widget.expense.dueAmount}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomDecoration.uTextField('Payment Method', widget.expense.paymentMethod.toUpperCase()),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: CustomDecoration.uTextField('Reference No.', widget.expense.referenceNo ?? '-'),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: CustomDecoration.uTextField('Date', widget.controller.formatDate(widget.expense.createdAt)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Created Location row
            isAdmin && _lat != null && _lng != null
                ? InkWell(
                    onTap: () => LocationService.instance.openMap(_lat!, _lng!),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Created Location: $locationDisplay',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new, size: 14, color: Colors.orange),
                        ],
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(73, 249, 251, 250),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Created Location: $locationDisplay',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
            if (widget.expense.description != null && widget.expense.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              CustomDecoration.uTextField('Description', widget.expense.description!),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (Authz.can(Permissions.expenseEdit))
                  TextButton.icon(
                    onPressed: () => widget.controller.showEditExpenseDialog(widget.expense),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                const SizedBox(width: 8),
                if (Authz.can(Permissions.expenseDelete))
                  TextButton.icon(
                    onPressed: () => widget.controller.confirmDeleteExpense(widget.expense),
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
