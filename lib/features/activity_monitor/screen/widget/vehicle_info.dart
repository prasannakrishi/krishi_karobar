import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
import '../../controllers/monitor_controller.dart';

class VehicleInfo extends StatelessWidget {
  const VehicleInfo({super.key, required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.vehicleNumber,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Vehicle Number'),
                onTap: () {
                  controller.showMessage(
                    'Vehicle required',
                    'Please select vehicle from Setting.',
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller.vehicleType,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Vehicle Type'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.vehicleOwner,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Owner'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Obx(
                    () => TextFormField(
                  controller: controller.driver,
                  readOnly: true,
                  onTap: () => _showDriverPicker(context),
                  decoration: InputDecoration(
                    labelText: 'Driver *',
                    suffixIcon: controller.isLoginUserDriver
                        ? null
                        : const Icon(Icons.keyboard_arrow_down_rounded),
                    errorText: controller.driverWarning.value
                        ? 'Please select a driver'
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDriverPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final drivers = controller.cache.users.values
            .where((u) => u.roles.contains('driver')).toList();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Driver',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: drivers.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No drivers available. Assign one '
                          'from Settings > Users.',
                      textAlign: TextAlign.center,
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: drivers.length,
                    itemBuilder: (_, index) {
                      final UserModel user = drivers[index];
                      return ListTile(
                        dense: true,
                        title: Text(user.fullname),
                        subtitle: Text(user.phone),
                        onTap: () {
                          controller.selectDriver(user);
                          Get.back();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
