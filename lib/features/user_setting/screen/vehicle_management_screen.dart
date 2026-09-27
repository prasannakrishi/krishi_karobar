import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/common/widgets/app_scaffold.dart';
import '../../../common/widgets/access_denied_screen.dart';
import '../../../services/services.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../controller/vehicle_controller.dart';
import 'widgets/vehicle_form.dart';

class VehicleManagementScreen extends StatelessWidget {
  VehicleManagementScreen({super.key});

  final controller = Get.isRegistered<VehicleController>()
      ? Get.find<VehicleController>()
      : Get.put(VehicleController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    // Route guard (spec section 16).
    if (!Authz.can(Permissions.vehicleView)) {
      return const AccessDeniedScreen(title: 'Vehicles');
    }

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
                      onChanged: controller.vehiclesList.isEmpty
                          ? null
                          : (_) => controller.toggleSelectAll(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Center(
                  child: Text(
                    'Vehicles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (!multi && selected && Authz.can(Permissions.vehicleEdit))
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      final vehicle = controller.selectedListVehicle;
                      if (vehicle == null) return;

                      controller.startEdit(vehicle);
                      Get.to(() => const VehicleForm());
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (selected && Authz.can(Permissions.vehicleDelete))
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: controller.deleteSelectedVehicles,
                    icon: const Icon(Icons.delete_outline),
                  ),
                if (Authz.can(Permissions.vehicleCreate))
                  IconButton(
                    tooltip: 'Add',
                    onPressed: () {
                      controller.startAdd();
                      Get.to(() => const VehicleForm());
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
        // Data scope (spec section 8): Drivers/Vehicle Owners only see
        // vehicles assigned to them; everyone else with vehicle.view sees
        // every vehicle.
        final visibleVehicles = controller.vehiclesList
            .where(Authz.canViewVehicle)
            .toList();

        if (controller.isLoading.value && visibleVehicles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (visibleVehicles.isEmpty) {
          return const Center(child: Text('No vehicles found'));
        }

        return uDataTable(
          columns: const [
            SizedBox(width: 42, child: Text('')),
            Text('Number'),
            Text('Name'),
            Text('Owner'),
            Text('Status'),
          ],
          rowValues: List.generate(visibleVehicles.length, (index) {
            final vehicle = visibleVehicles[index];
            final selected = controller.isRowSelected(vehicle.id);

            final owner = controller.allUsers.firstWhereOrNull(
              (user) => user.id == vehicle.ownerId,
            );
            final ownerName = owner?.fullname ?? '—';
            final status = vehicle.isActive ? 'Active' : 'Inactive';

            void onTap() {
              if (controller.selectionMode.value) {
                controller.toggleSelection(vehicle.id);
              } else {
                controller.selectRow(vehicle.id);
              }
            }

            void onLongPress() => controller.startMultiSelect(vehicle.id);

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
                          ? (_) => controller.toggleSelection(vehicle.id)
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
                    vehicle.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Text(
                  vehicle.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Text(
                  ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
