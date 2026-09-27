import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:krishi_karobar/common/widgets/app_scaffold.dart';
import 'package:krishi_karobar/common/widgets/appbar.dart';
import 'package:krishi_karobar/features/user_setting/controller/vehicle_controller.dart';

class VehicleSelectScreen extends StatelessWidget {
  const VehicleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<VehicleController>()
        ? Get.find<VehicleController>()
        : Get.put(VehicleController(), permanent: true);

    return UAppScaffold(
      transparentBackground: true,
      extendBodyBehindAppBar: false,
      appBar: UAppBar(
        title: 'Select Vehicle',
        showBackArrow: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.vehiclesList.isEmpty) {
          return const Center(child: Text('No vehicles found. Register one!'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: controller.vehiclesList.length,
          itemBuilder: (context, index) {
            final vehicle = controller.vehiclesList[index];
            final isSelected = controller.selectedVehicle.value?.id == vehicle.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: isSelected ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.green : Colors.transparent,
                  width: 2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  controller.setDefaultVehicle(vehicle);
                  Get.back();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isSelected ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                        child: Icon(
                          Iconsax.truck,
                          size: 18,
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          vehicle.number,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? Colors.green : null,
                          ),
                        ),
                      ),
                      Text(
                        vehicle.name,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
