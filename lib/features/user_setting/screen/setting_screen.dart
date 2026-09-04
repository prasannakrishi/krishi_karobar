import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:krishi_karobar/common/widgets/appbar.dart';
import 'package:krishi_karobar/common/widgets/settings_menu_title.dart';
import 'package:krishi_karobar/features/user_setting/screen/widgets/user_profile.dart';
import 'package:krishi_karobar/features/user_setting/screen/widgets/vehicle_reg_form.dart';
import '../controller/setting_controller.dart';
import '../controller/vehicle_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    final vController = Get.put(VehicleController());

    return Scaffold(
      appBar: UAppBar(title: 'Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// -- User Profile Card
            const UserProfile(),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 5),

            /// -- Menu Items
            Obx(() => Column(
              children: [
                USettingsMenuTile(
                  icon: Iconsax.truck,
                  title: 'Select Vehicles',
                  subtitle: vController.selectedVehicle.value?.number != null && vController.selectedVehicle.value!.number.isNotEmpty
                      ? 'Selected: ${vController.selectedVehicle.value!.number}'
                      : 'No vehicle selected',
                  trailing: IconButton(
                    onPressed: () {
                      vController.clearVehicle();
                      _showRegistrationForm(context);
                    },
                    icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
                  ),
                  onTap: () => vController.isSelectionOpen.toggle(),
                ),
                if (vController.isSelectionOpen.value)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        if (vController.isLoading.value)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ))
                        else if (vController.vehiclesList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Text('No vehicles found.'),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: vController.vehiclesList.length,
                            itemBuilder: (context, index) {
                              final vehicle = vController.vehiclesList[index];
                              final isSelected = vController.selectedVehicle.value?.guid == vehicle.guid;
                              return Container(

                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? Colors.green : Colors.transparent,
                                    width: 2,
                                  ),
                                  color: isSelected ? Colors.green.withValues(alpha: 0.05) : Colors.transparent,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    vController.setDefaultVehicle(vehicle);
                                    vController.isSelectionOpen.value = false;
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(Iconsax.truck, color: isSelected ? Colors.green : Colors.grey, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            vehicle.number,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isSelected ? Colors.green : null,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          vehicle.name,
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        TextButton.icon(
                          onPressed: () {
                            vController.isSelectionOpen.value = false;
                            _showRegistrationForm(context);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Register New Vehicle'),
                        ),
                      ],
                    ),
                  ),
              ],
            )),
            
            USettingsMenuTile(
// ... (rest of the file remains same, I will delete the unused _showVehicleSelectionDialog)
              icon: Iconsax.key,
              title: 'Change Password',
              subtitle: 'Update your login password for security',
              onTap: () {},
            ),
            USettingsMenuTile(
              icon: Iconsax.notification,
              title: 'Notifications',
              subtitle: 'Manage your app notifications',
              trailing: Switch(value: true, onChanged: (value) {}),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => controller.logout(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegistrationForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 15),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Register New Vehicle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                VehiclesForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

