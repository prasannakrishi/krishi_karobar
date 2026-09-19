import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../common/widgets/app_scaffold.dart';
import '../../../common/widgets/appbar.dart';
import '../../../common/widgets/settings_menu_title.dart';
import '../../../features/user_setting/screen/user_management_screen.dart';
import '../../../services/services.dart';
import 'package:krishi_karobar/features/controllers.dart';
import 'profile_screen.dart';
import 'service_management_screen.dart';
import 'vehicle_management_screen.dart';
import 'widgets/user_profile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    final vehicleController = Get.isRegistered<VehicleController>()
        ? Get.find<VehicleController>()
        : Get.put(VehicleController(), permanent: true);

    return UAppScaffold(
      transparentBackground: true,
      extendBodyBehindAppBar: false,
      appBar: const UAppBar(title: 'Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const UserProfile(),
            const SizedBox(height: 10),
            _SelectedVehicleRow(controller: vehicleController),
            const SizedBox(height: 5),
            const Divider(),
            Obx(
              () => USettingsMenuTile(
                icon: Iconsax.setting_2,
                title: 'Management',
                subtitle: 'Manage users, vehicles and services',
                trailing: Icon(
                  controller.managementExpanded.value
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                onTap: controller.toggleManagement,
              ),
            ),
            Obx(() {
              if (!controller.managementExpanded.value) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: Column(
                  children: [
                    if (Authz.can(Permissions.userView))
                      USettingsMenuTile(
                        icon: Iconsax.profile_2user,
                        title: 'Users',
                        subtitle: 'Manage organization users',
                        onTap: () {
                          Get.to(() => UserManagementScreen());
                        },
                      ),
                    if (Authz.can(Permissions.vehicleView))
                      USettingsMenuTile(
                        icon: Iconsax.truck,
                        title: 'Vehicles',
                        subtitle: 'Manage registered vehicles',
                        onTap: () {
                          Get.to(() => VehicleManagementScreen());
                        },
                      ),
                    if (Authz.can(Permissions.serviceView))
                      USettingsMenuTile(
                        icon: Iconsax.setting_4,
                        title: 'Services',
                        subtitle: 'Manage available services',
                        onTap: () {
                          Get.to(() => ServiceManagementScreen());
                        },
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Obx(
              () => USettingsMenuTile(
                icon: Iconsax.setting,
                title: 'Preferences',
                subtitle: 'App and account preferences',
                trailing: Icon(
                  controller.preferencesExpanded.value
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                onTap: controller.togglePreferences,
              ),
            ),
            Obx(() {
              if (!controller.preferencesExpanded.value) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: Column(
                  children: [
                    USettingsMenuTile(
                      icon: Iconsax.user_edit,
                      title: 'Profile',
                      subtitle: 'View and edit your profile',
                      onTap: () {
                        Get.to(() => const ProfileScreen());
                      },
                    ),
                    USettingsMenuTile(
                      icon: Iconsax.key,
                      title: 'Change Password',
                      subtitle: 'Update your login password',
                      onTap: () {},
                    ),
                    USettingsMenuTile(
                      icon: Iconsax.notification,
                      title: 'Notifications',
                      subtitle: 'Manage app notifications',
                      trailing: Switch(value: true, onChanged: (_) {}),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: controller.logout,
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
}

class _SelectedVehicleRow extends StatelessWidget {
  const _SelectedVehicleRow({required this.controller});

  final VehicleController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedVehicle = controller.selectedVehicle.value;

      final assigned = controller.assignedVehiclesForUser(
        LoginController.loginUser.id,
      );

      if (assigned.isEmpty) {
        return UDetailRow(
          value: 'Not Assigned',
          icon: Iconsax.truck,
        );
      }

      if (assigned.length == 1) {
        return UDetailRow(
          value: assigned.first.number,
          icon: Iconsax.truck,
        );
      }

      final selected = selectedVehicle != null &&
          assigned.any((v) => v.id == selectedVehicle.id)
          ? selectedVehicle
          : null;

      return Row(
        children: [
          const Icon(Iconsax.truck, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: selected?.id,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              decoration: const InputDecoration(
                labelText: 'Selected Vehicle',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select Vehicle'),
              items: assigned
                  .map(
                    (v) => DropdownMenuItem<String>(
                      value: v.id,
                      child: Text(v.number, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;

                final vehicle = assigned.firstWhereOrNull((v) => v.id == id);

                if (vehicle != null) {
                  controller.setDefaultVehicle(vehicle, showMessage: false);
                }
              },
            ),
          ),
        ],
      );
    });
  }
}
