import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/appbar.dart';
import '../../../utils/constants/enums.dart';
import '../controllers/monitor_controller.dart';
import '../controllers/timer_controller.dart';
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
      appBar: UAppBar(title: 'Activity Monitor'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        child: Column(
          children: [
            Obx(
              () => _Section(
                title: 'Vehicle Information',
                summary:
                    controller.selectedVehicle.value?.number ??
                    'Select vehicle',
                collapsed: controller.vehicleCollapsed.value,
                onTap: controller.vehicleCollapsed.toggle,
                child: VehicleInfo(controller: controller),
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => _Section(
                title: 'Customer Information',
                summary:
                    controller.selectedCustomer.value?.name ??
                    (controller.customerName.text.isEmpty
                        ? 'Enter customer'
                        : controller.customerName.text),
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
      bottomNavigationBar: _MonitorControls(controller: controller),
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
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  if (collapsed)
                    Flexible(
                      child: Text(
                        summary,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
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

class _MonitorControls extends StatelessWidget {
  const _MonitorControls({required this.controller});
  final MonitorController controller;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Obx(() {
          final state = controller.timerController.state.value;
          if (state == TimerState.initial) {
            return _button(
              context,
              'START',
              Icons.play_arrow,
              controller.startActivity,
            );
          }
          if (state == TimerState.running) {
            return Row(
              children: [
                Expanded(
                  child: _button(
                    context,
                    'PAUSE',
                    Icons.pause,
                    controller.pauseActivity,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _button(
                    context,
                    'STOP',
                    Icons.stop,
                    controller.stopActivity,
                  ),
                ),
              ],
            );
          }
          if (state == TimerState.paused) {
            return Row(
              children: [
                Expanded(
                  child: _button(
                    context,
                    'RESUME',
                    Icons.play_arrow,
                    controller.resumeActivity,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _button(
                    context,
                    'STOP',
                    Icons.stop,
                    controller.stopActivity,
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: _button(
                  context,
                  'SAVE',
                  Icons.save,
                  controller.saveActivity,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _button(
                  context,
                  'RESET',
                  Icons.refresh,
                  controller.timerController.reset,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
    );
  }
}
