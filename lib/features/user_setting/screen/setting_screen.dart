import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../common/widgets/appbar.dart';
import '../../../common/widgets/settings_menu_title.dart';
import '../../../features/user_setting/screen/user_management_screen.dart';
import 'package:krishi_karobar/features/controllers.dart';
import 'profile_screen.dart';
import 'widgets/user_profile.dart';
import 'widgets/vehicle_select_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const UAppBar(
        title: 'Settings',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const UserProfile(),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 5),
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
            Obx(
                  () {
                if (!controller.managementExpanded.value) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                  ),
                  child: Column(
                    children: [
                      USettingsMenuTile(
                        icon: Iconsax.profile_2user,
                        title: 'Users',
                        subtitle: 'Manage organization users',
                        onTap: () {
                          Get.to(
                                () => UserManagementScreen(),
                          );
                        },
                      ),
                      USettingsMenuTile(
                        icon: Iconsax.truck,
                        title: 'Vehicles',
                        subtitle: 'Manage registered vehicles',
                        onTap: () {
                          Get.to(
                                () => const VehicleSelectScreen(),
                          );
                        },
                      ),
                      USettingsMenuTile(
                        icon: Iconsax.setting_4,
                        title: 'Services',
                        subtitle: 'Manage available services',
                        onTap: () {},
                      ),
                    ],
                  ),
                );
              },
            ),
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
            Obx(
                  () {
                if (!controller.preferencesExpanded.value) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                  ),
                  child: Column(
                    children: [
                      USettingsMenuTile(
                        icon: Iconsax.user_edit,
                        title: 'Profile',
                        subtitle: 'View and edit your profile',
                        onTap: () {
                          Get.to(
                                () => const ProfileScreen(),
                          );
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
                        trailing: Switch(
                          value: true,
                          onChanged: (_) {},
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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