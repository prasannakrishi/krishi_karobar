import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/features/recent_activity/screen/activities_screen.dart';
import '../../activity_monitor/screen/monitor/monitor_screen.dart';
import '../../home/screen/home_screen.dart';
import '../../user_setting/screen/setting_screen.dart';

class NavigationController extends GetxController {

  final Rx<int> selectedIndex = 0.obs;

  late final screens = [
    HomeScreen(),
    MonitorScreen(),
    ActivityScreen(),
    SettingsScreen()
  ];

  late final PageController pageController;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: selectedIndex.value);

  }

  @override
  void onClose() {

    pageController.dispose();
    super.onClose();
  }
  void onPageChanged(int index) {
    selectedIndex.value = index;
  }

  void onTabSelected(int index) {
    selectedIndex.value = index;
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
