import 'package:flutter/material.dart';
import '../../../../../utils/theme/widget_themes/custom_decoration.dart';
import '../../../controllers/monitor_controller.dart';

class VehicleInfo extends StatelessWidget {
  final MonitorController controller;

  const VehicleInfo({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.vehicleNumber,
                decoration: CustomDecoration.uInputDecoration(labelText: 'Vehicle Number'),
                readOnly: true, // Read-only as per request
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller.driver,
                decoration: CustomDecoration.uInputDecoration(labelText: 'Driver Name'),
                readOnly: true, // Read-only
              ),
            ),
          ],
        ),
      ],
    );
  }
}
