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
        padding: const EdgeInsets.fromLTRB(3, 8, 3, 10),
        child: Column(
          children: [
            Obx(
              () => _Section(
                title: 'VEHICLE INFO',
                summary:"${controller.selectedDriver.value?.name.padRight(10)}\n${controller.selectedVehicle.value?.number}",
                collapsed: controller.vehicleCollapsed.value,
                onTap: controller.vehicleCollapsed.toggle,
                child: VehicleInfo(controller: controller),
              ),
            ),
            const SizedBox(height: 5),
            Obx(
              () => _Section(
                title: 'CUSTOMER INFO',
                summary: controller.customerSummary.value,
                collapsed: controller.customerCollapsed.value,
                onTap: controller.customerCollapsed.toggle,
                // ignore: sort_child_properties_last
                child: CustomerForm(controller: controller),
              ),
            ),
            const SizedBox(height: 5),
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
    super.key,
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
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
              child: child,
            ),
        ],
      ),
    );
  }
}
