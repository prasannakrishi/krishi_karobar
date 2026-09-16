import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/common/widgets/app_scaffold.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../controller/service_controller.dart';
import 'widgets/service_form.dart';

class ServiceManagementScreen extends StatelessWidget {
  ServiceManagementScreen({super.key});

  final controller = Get.put(ServiceController());

  @override
  Widget build(BuildContext context) {
    return UAppScaffold(
      transparentBackground: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Obx(() {
          final selected = controller.hasSelection;
          final multi = controller.selectionMode.value;

          return SizedBox(
            height: kToolbarHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 48,
                  child: Center(
                    child: Checkbox(
                      value: controller.isAllSelected
                          ? true
                          : controller.isPartiallySelected
                          ? null
                          : false,
                      tristate: true,
                      onChanged: controller.services.isEmpty
                          ? null
                          : (_) => controller.toggleSelectAll(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Center(
                  child: Text(
                    'Services',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (!multi && selected)
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      final service = controller.selectedService;
                      if (service == null) return;

                      controller.startEdit(service);
                      Get.to(() => ServiceForm());
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (selected)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: controller.deleteSelectedServices,
                    icon: const Icon(Icons.delete_outline),
                  ),
                IconButton(
                  tooltip: 'Add',
                  onPressed: () {
                    controller.startAdd();
                    Get.to(() => ServiceForm());
                  },
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
      body: Obx(() {
        if (controller.services.isEmpty) {
          return const Center(child: Text('No services found'));
        }

        return uDataTable(
          columns: const [
            SizedBox(width: 42, child: Text('')),
            Text('Name'),
            Text('ID'),
            Text('Rate'),
            Text('Status'),
          ],
          rowValues: List.generate(controller.services.length, (index) {
            final service = controller.services[index];
            final selected = controller.selectedServiceIds.contains(service.id);

            final rate =
                'रु ${service.rate.toStringAsFixed(0)} / '
                '${service.unit}';
            final status = service.isActive ? 'Active' : 'Inactive';

            void onTap() {
              if (controller.selectionMode.value) {
                controller.toggleSelection(service.id);
              } else {
                controller.selectService(service.id);
              }
            }

            void onLongPress() => controller.startMultiSelect(service.id);

            return [
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: Checkbox(
                      value: selected,
                      onChanged: controller.selectionMode.value
                          ? (_) => controller.toggleSelection(service.id)
                          : null,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Text(
                  service.uId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Text(rate, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ];
          }),
        );
      }),
    );
  }
}
