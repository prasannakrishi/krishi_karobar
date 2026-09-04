import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:krishi_karobar/utils/helper/helper_functions.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';
import '../../controller/vehicle_controller.dart';
import '../../../../models/user_model.dart';

class VehiclesForm extends StatelessWidget {
  const VehiclesForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VehicleController>();
    
    return Stack(
      children: [
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.vNumberController,
                    decoration: CustomDecoration.uInputDecoration(
                      labelText: 'Vehicle Number',
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: TextField(
                    controller: controller.vTypeController,
                    decoration: CustomDecoration.uInputDecoration(
                      labelText: 'Vehicle Type',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller.vNameController,
              decoration: CustomDecoration.uInputDecoration(
                labelText: 'Vehicle Name (Brand/Model)',
                prefixIcon: const Icon(Iconsax.truck),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.vOwnerController,
                    decoration: CustomDecoration.uInputDecoration(
                      labelText: 'Owner Name',
                      prefixIcon: const Icon(Iconsax.user),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: controller.vModelController,
                    decoration: CustomDecoration.uInputDecoration(
                      labelText: 'Model Year',
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      controller.saveVehicle();
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text(
                      'Register',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Owner Selection Dropdown
        Obx(() {
          if (controller.filteredOwners.isEmpty) return const SizedBox.shrink();
          return UHelperFunctions.floatingDropdown<UserModel>(
            top: 135, // Adjust based on layout
            items: controller.filteredOwners,
            onClose: () => controller.filteredOwners.clear(),
            titleBuilder: (u) => Text(u.name),
            subtitleBuilder: (u) => Text(u.phone),
            onTap: (u) => controller.selectOwner(u),
          );
        }),
      ],
    );
  }
}

