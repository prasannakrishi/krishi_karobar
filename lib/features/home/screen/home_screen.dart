import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../common/widgets/appbar.dart';
import '../controller/home_controller.dart';



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: UAppBar(
        title: 'Dashboard',
      ),
      body: SingleChildScrollView(

        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// Welcome Message
            Obx(() {
              if (controller.isLoading.value) {
                return const Text('Loading user...');
              }
              return Text(
                'Welcome, ${controller.user.value?.fullname ?? 'User'}!',
                style: Theme.of(context).textTheme.headlineSmall,
              );
            }),

            const SizedBox(height: 24),

            /// Summary Grid (Example)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                buildSummaryCard(context, 'Today\'s Trips', '5', Iconsax.truck_fast),
                buildSummaryCard(context, 'Total Customers', '120', Iconsax.people),
                // Add more summary cards as needed
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget to build summary cards.
  Widget buildSummaryCard(BuildContext context, String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
