import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../common/widgets/app_scaffold.dart';
import '../../../common/widgets/appbar.dart';
import '../controller/home_controller.dart';
import '../widgets/home_header.dart';
import '../widgets/home_summary_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());

    return UAppScaffold(
      extendBodyBehindAppBar: false,
      appBar: UAppBar(title: 'Dashboard'),
      body: Obx(
            () => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(
                name: controller.user.value?.fullname ?? 'User',
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.15,
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
                  HomeSummaryCard(
                    title: 'Total Vehicles',
                    value: controller.totalVehicles.toString(),
                    icon: Iconsax.truck_fast,
                  ),
                  HomeSummaryCard(
                    title: 'Total Services',
                    value: controller.totalServices.toString(),
                    icon: Iconsax.setting_2,
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