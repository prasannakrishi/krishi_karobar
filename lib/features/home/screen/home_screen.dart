import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../common/widgets/app_scaffold.dart';
import '../../../common/widgets/appbar.dart';
import '../controller/home_controller.dart';
import '../widgets/home_summary_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());

    return UAppScaffold(
      transparentBackground: true,
      extendBodyBehindAppBar: false,
      appBar: const UAppBar(title: 'Dashboard'),
      body: Obx(
        () => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Selector or Assigned Vehicle Display
              if (controller.canSwitchVehicle)
                Row(
                  children: [
                    const Icon(Iconsax.truck, size: 20),
                    const SizedBox(width: 8),
                    const Text('Vehicle Filter:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: controller.vehicles.any((v) => v.id == controller.selectedVehicleId.value)
                            ? controller.selectedVehicleId.value
                            : 'all',
                        isDense: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Vehicles')),
                          ...controller.vehicles.map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.number),
                              )),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            controller.selectedVehicleId.value = val;
                          }
                        },
                      ),
                    ),
                  ],
                )
              else if (controller.assignedVehicles.isNotEmpty)
                Row(
                  children: [
                    const Icon(Iconsax.truck, size: 20, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Text('Assigned Vehicle:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.assignedVehicles.first.number,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal),
                      ),
                    ),
                  ],
                ),
              if (controller.canSwitchVehicle || controller.assignedVehicles.isNotEmpty)
                const SizedBox(height: 16),

              // Reports (Daily, Weekly, Monthly, Yearly)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _ReportCard(
                    title: 'Daily Report',
                    income: controller.dailyIncome,
                    expense: controller.dailyExpense,
                    icon: Iconsax.calendar_1,
                  ),
                  _ReportCard(
                    title: 'Weekly Report',
                    income: controller.weeklyIncome,
                    expense: controller.weeklyExpense,
                    icon: Iconsax.calendar_2,
                  ),
                  _ReportCard(
                    title: 'Monthly Report',
                    income: controller.monthlyIncome,
                    expense: controller.monthlyExpense,
                    icon: Iconsax.calendar,
                  ),
                  _ReportCard(
                    title: 'Yearly Report',
                    income: controller.yearlyIncome,
                    expense: controller.yearlyExpense,
                    icon: Iconsax.chart,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Stats
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  HomeSummaryCard(
                    title: "Today's Activities",
                    value: controller.todayActivities.toString(),
                    icon: Iconsax.activity,
                  ),
                  HomeSummaryCard(
                    title: 'Total Customers',
                    value: controller.totalCustomers.toString(),
                    icon: Iconsax.people,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.income,
    required this.expense,
    required this.icon,
  });

  final String title;
  final double income;
  final double expense;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Income:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('रु ${income.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expense:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('रु ${expense.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('रु ${net.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: net >= 0 ? Colors.teal : Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
