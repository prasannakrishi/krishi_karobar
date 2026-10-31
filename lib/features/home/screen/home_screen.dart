import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../common/widgets/app_scaffold.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../controller/home_controller.dart';
import '../widgets/dashboard_filter_bar.dart';
import '../widgets/dashboard_info_card.dart';
import '../widgets/dashboard_quick_action.dart';
import '../widgets/dashboard_recent_activity_tile.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/home_summary_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());

    return UAppScaffold(
      transparentBackground: false,
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(controller, context),
      body: Obx(
        () {
          // Access reactive values so GetX Obx always has registered observables
          controller.selectedVehicleId.value;
          controller.selectedPeriod.value;
          controller.pendingQueueCount.value;

          return RefreshIndicator(
            onRefresh: controller.refreshDashboard,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(wide ? 14 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardWelcome(controller: controller),
                      const SizedBox(height: 10),
                      DashboardFilterBar(controller: controller),
                      const SizedBox(height: 10),
                      _SummaryGrid(controller: controller, wide: wide),
                      const SizedBox(height: 22),
                      _QuickActions(controller: controller, wide: wide),
                      const SizedBox(height: 22),
                      _VehiclePerformance(controller: controller),
                      const SizedBox(height: 22),
                      _OperationalOverview(controller: controller, wide: wide),
                      const SizedBox(height: 22),
                      _RecentActivities(controller: controller),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    HomeController controller,
    BuildContext context,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: AppBar(
        backgroundColor: const Color(0xFF1D8024),
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/logos/company_Logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Iconsax.tree,
                  color: Color(0xFF1B5E20),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 9),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KRISHI KAROBAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: .4,
                  ),
                ),
                Text(
                  'Agri Machinery Management',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Obx(() {
            final count = controller.pendingQueueCount.value;
            if (count <= 0) return const SizedBox.shrink();
            return IconButton(
              tooltip: '$count records waiting to sync. Tap to sync now.',
              icon: Badge(
                label: Text('$count'),
                child: const Icon(Iconsax.refresh, color: Colors.white),
              ),
              onPressed: () async {
                await controller.triggerSync();
                successSnackBar(title: 'Syncing', message: 'Syncing offline records...');
              },
            );
          }),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Iconsax.notification, color: Colors.white),
            onPressed: () => controller.openNotifications(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: controller.openProfile,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Colors.white,
                child: Text(
                  controller.userInitial,
                  style: const TextStyle(
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardWelcome extends StatelessWidget {
  const _DashboardWelcome({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'नमस्कार, ${controller.loginUserName}!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                controller.currentNepaliDateFormatted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => controller.triggerSync(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: controller.syncStatusBgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: controller.syncStatusColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: controller.syncStatusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  controller.syncStatusText,
                  style: TextStyle(
                    color: controller.syncStatusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.controller, required this.wide});

  final HomeController controller;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      const HomeSummaryCard(
        title: 'कुल सेवा रकम',
        value: '',
        icon: Iconsax.money_4,
        color: Color(0xFF1B5E20),
      ),
      const HomeSummaryCard(
        title: 'संकलित रकम',
        value: '',
        icon: Iconsax.wallet_check,
        color: Color(0xFF0D47A1),
      ),
      const HomeSummaryCard(
        title: 'बाँकी (Due)',
        value: '',
        icon: Iconsax.receipt_minus,
        color: Color(0xFFE65100),
      ),
      const HomeSummaryCard(
        title: 'कुल खर्च',
        value: '',
        icon: Iconsax.money_send,
        color: Color(0xFFB71C1C),
      ),
      const HomeSummaryCard(
        title: 'संचालन नतिजा',
        value: '',
        icon: Iconsax.chart_success,
        color: Color(0xFF4A148C),
      ),
      const HomeSummaryCard(
        title: 'कुल गतिविधि',
        value: '',
        icon: Iconsax.activity,
        color: Color(0xFF006064),
      ),
    ];

    final values = [
      'रु. ${controller.totalServiceAmount.toStringAsFixed(0)}',
      'रु. ${controller.amountCollected.toStringAsFixed(0)}',
      'रु. ${controller.outstandingDue.toStringAsFixed(0)}',
      'रु. ${controller.totalExpenses.toStringAsFixed(0)}',
      'रु. ${controller.operatingResult.toStringAsFixed(0)}',
      controller.totalActivitiesCount.toString(),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 3 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 2,
        childAspectRatio: wide ? 1.3 : 2.8,
      ),
      itemBuilder: (_, index) {
        final card = cards[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: HomeSummaryCard(
            title: card.title,
            value: values[index],
            icon: card.icon,
            color: card.color,
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller, required this.wide});

  final HomeController controller;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final actions = [
      DashboardQuickAction(
        title: 'Monitor',
        subtitle: 'गतिविधि हेर्नु',
        icon: Iconsax.radar,
        color: const Color(0xFF1B5E20),
        backgroundColor: const Color(0xFFE8F5E9),
        onTap: controller.onNavigateToMonitor,
      ),
      DashboardQuickAction(
        title: 'Add Expense',
        subtitle: 'खर्च थप्नु',
        icon: Iconsax.add_circle,
        color: const Color(0xFF0D47A1),
        backgroundColor: const Color(0xFFE3F2FD),
        onTap: controller.onOpenAddExpense,
      ),
      DashboardQuickAction(
        title: 'Records',
        subtitle: 'रेकर्ड हेर्नु',
        icon: Iconsax.document_text,
        color: const Color(0xFFE65100),
        backgroundColor: const Color(0xFFFFF3E0),
        onTap: controller.onNavigateToRecords,
      ),
      DashboardQuickAction(
        title: 'Customers',
        subtitle: 'ग्राहक सूची',
        icon: Iconsax.people,
        color: const Color(0xFF4A148C),
        backgroundColor: const Color(0xFFF3E5F5),
        onTap: controller.onNavigateToCustomers,
      ),
    ];

    return Column(
      children: [
        const DashboardSectionHeader(title: 'QUICK ACTIONS'),
        const SizedBox(height: 9),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 4 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: wide ? 1.0 : 2.8,
          ),
          itemBuilder: (_, index) => actions[index],
        ),
      ],
    );
  }
}

class _VehiclePerformance extends StatelessWidget {
  const _VehiclePerformance({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final rows = controller.vehiclePerformanceList;

    return Column(
      children: [
        DashboardSectionHeader(
          title: 'VEHICLE PERFORMANCE',
          trailing: controller.selectedPeriod.value,
        ),
        const SizedBox(height: 9),
        if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No vehicle data for the selected filter.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          )
        else
          CustomVehicleDataTable(items: rows),
      ],
    );
  }
}

class CustomVehicleDataTable extends StatelessWidget {
  const CustomVehicleDataTable({super.key, required this.items});

  final List<VehiclePerformanceItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)), textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('Service Amt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)), textAlign: TextAlign.right)),
                Expanded(flex: 3, child: Text('Due Amt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          // Data Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.truck, size: 15, color: Color(0xFF1B5E20)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.vehicleNumber,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.activitiesCount.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'रु. ${item.serviceAmount.toStringAsFixed(0)}',
                        style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w700, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'रु. ${item.dueAmount.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OperationalOverview extends StatelessWidget {
  const _OperationalOverview({
    required this.controller,
    required this.wide,
  });

  final HomeController controller;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final due = DashboardInfoCard(
      title: 'CUSTOMER DUE',
      icon: Iconsax.people,
      accentColor: const Color(0xFFE65100),
      isTransparent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Due',
            style: TextStyle(fontSize: 12, color: Color(0xE5000000)),
          ),
          Text(
            'रु. ${controller.totalCustomerDue.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE65100),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${controller.customersWithDueCount} customers with due',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF050505),
                ),
              ),
              _ActionLink(
                label: 'View Details',
                onTap: controller.onNavigateToCustomers,
              ),
            ],
          )
        ],
      ),
    );

    final operations = DashboardInfoCard(
      title: "TODAY'S OPERATIONS",
      icon: Iconsax.activity,
      isTransparent: true,
      child: Column(
        children: [
          _OperationRow(
            label: 'Activities',
            value: controller.todayActivities.toString(),
          ),
          _OperationRow(
            label: 'Running',
            value: controller.todayRunningActivities.toString(),
            color: Colors.blue,
          ),
          _OperationRow(
            label: 'Completed',
            value: controller.todayCompletedActivities.toString(),
            color: Colors.green,
          ),
          _OperationRow(
            label: 'Due',
            value: controller.todayDueActivities.toString(),
            color: Colors.orange,
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: _ActionLink(
              label: 'View All',
              onTap: controller.onNavigateToRecords,
            ),
          ),
        ],
      ),
    );

    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: due),
              const SizedBox(width: 10),
              Expanded(child: operations),
            ],
          )
        : Column(
            children: [
              due,
              const SizedBox(height: 10),
              operations,
            ],
          );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dotColor = color ?? const Color(0xFF1B5E20);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.arrow_forward,
              size: 11,
              color: Color(0xFF1B5E20),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivities extends StatelessWidget {
  const _RecentActivities({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final activities = controller.recentActivities;

    return Column(
      children: [
        DashboardSectionHeader(
          title: 'RECENT ACTIVITIES',
          trailing: 'View All →',
          onTrailingTap: controller.onNavigateToRecords,
        ),
        const SizedBox(height: 8),
        if (activities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No recent activities found.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 7),
            itemBuilder: (_, index) => DashboardRecentActivityTile(
              activity: activities[index],
            ),
          ),
      ],
    );
  }
}
