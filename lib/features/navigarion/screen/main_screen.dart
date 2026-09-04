import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../controller/navigation_controller.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller if not already initialized
    final controller = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : Get.put(NavigationController());

    return Scaffold(
      body: PageView(
        controller: controller.pageController,
        onPageChanged: controller.onPageChanged,
        children: controller.screens,
      ),
      bottomNavigationBar: Obx(
            () => BottomNavigationBar(
          currentIndex: controller.selectedIndex.value,
          onTap: controller.onTabSelected,
          items: const [
            BottomNavigationBarItem(icon: Icon(Iconsax.home_2), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Iconsax.monitor), label: 'Monitor'),
            BottomNavigationBarItem(icon: Icon(Iconsax.document_text), label: 'Activities'),
            BottomNavigationBarItem(icon: Icon(Iconsax.user), label: 'User'),
          ],
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
