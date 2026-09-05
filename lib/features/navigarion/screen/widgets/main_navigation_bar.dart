import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../utils/constants/text_strings.dart';
import '../../controller/navigation_controller.dart';

class MainNavigationBar extends GetView<NavigationController> {
  const MainNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => NavigationBar(
        selectedIndex: controller.selectedIndex.value,
        onDestinationSelected: controller.onTabSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Iconsax.home_2), label: UTexts.dashboard),
          NavigationDestination(
            icon: Icon(Iconsax.monitor),
            label: UTexts.dashboard,
          ),
          NavigationDestination(
            icon: Icon(Iconsax.document_text),
            label: UTexts.activities,
          ),
          NavigationDestination(
            icon: Icon(Iconsax.user),
            label: UTexts.settings,
          ),
        ],
      ),
    );
  }
}
