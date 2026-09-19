import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/features/activity_monitor/screen/widget/monitor_controls.dart';
import 'package:krishi_karobar/features/controllers.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/appbar.dart';
import 'widget/activity_details.dart';
import 'widget/customer_info.dart';
import 'widget/vehicle_info.dart';

class MonitorScreen extends GetView<MonitorController> {
  const MonitorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MonitorController>()) {
      Get.put(MonitorController());
    }
    return UAppScaffold(
      transparentBackground: true,
      extendBodyBehindAppBar: false,
      appBar: UAppBar(title: 'Activity Monitor'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 50),
        child: Column(
          children: [
            Obx(
              () => _Section(
                title: 'VEHICLE INFO',
                summary:"${controller.selectedDriver.value?.name.padRight(20)}\n${controller.selectedVehicle.value?.number}",
                collapsed: controller.vehicleCollapsed.value,
                onTap: controller.vehicleCollapsed.toggle,
                child: VehicleInfo(controller: controller),
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => _Section(
                title: 'CUSTOMER INFO',
                summary:"${controller.selectedCustomer.value?.name.padRight(20)}\n${controller.selectedCustomer.value?.uId}",
                collapsed: controller.customerCollapsed.value,
                onTap: controller.customerCollapsed.toggle,
                child: CustomerForm(controller: controller),
              ),
            ),
            const SizedBox(height: 12),
            ActivityForm(controller: controller),
          ],
        ),
      ),
      bottomNavigationBar: const MonitorControls(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.summary,
    required this.collapsed,
    required this.onTap,
    required this.child,
  });
  final String title;
  final String summary;
  final bool collapsed;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  if (collapsed) ...[
                      const SizedBox(width: 5),
                      Text(
                        summary,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                  ],
                  const SizedBox(width: 8),
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
        ],
      ),
    );
  }
}
