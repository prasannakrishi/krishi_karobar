import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:krishi_karobar/features/activity_monitor/screen/monitor_screen.dart';
import 'package:krishi_karobar/features/home/screen/home_screen.dart';
import 'package:krishi_karobar/features/recent_activity/screen/activities_screen.dart';
import 'package:krishi_karobar/features/user_setting/screen/setting_screen.dart';
import 'package:krishi_karobar/features/controllers.dart';

class NavigationController extends GetxController {
  final selectedIndex = 0.obs;

  late final PageController pageController;

  final screens = const [
    HomeScreen(),
    MonitorScreen(),
    ActivityScreen(),
    SettingsScreen(),
  ];

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: selectedIndex.value);
    if (!Get.isRegistered<SettingsController>()) {
      Get.put(SettingsController(), permanent: true);
    }
    if (!Get.isRegistered<VehicleController>()) {
      Get.put(VehicleController(), permanent: true);
    }
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  void onPageChanged(int index) => selectedIndex.value = index;

  void onTabSelected(int index) {
    if (index == selectedIndex.value) return;

    selectedIndex.value = index;
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
