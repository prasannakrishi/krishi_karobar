import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:krishi_karobar/common/widgets/app_scaffold.dart';
import '../controller/navigation_controller.dart';
import 'widgets/main_navigation_bar.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : Get.put(NavigationController());

    return UAppScaffold(
      body: PageView(
        controller: controller.pageController,
        onPageChanged: controller.onPageChanged,
        children: controller.screens,
      ),
      bottomNavigationBar: const MainNavigationBar(),
    );
  }
}
