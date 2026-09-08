import 'package:flutter/material.dart';

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
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller.vehicleOwner,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Owner'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.driver,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Driver'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller.supervisor,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Supervisor'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
