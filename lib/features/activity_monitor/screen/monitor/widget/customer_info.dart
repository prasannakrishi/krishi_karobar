import 'package:flutter/material.dart';
import 'package:krishi_karobar/features/activity_monitor/controllers/monitor_controller.dart';
import '../../../../../utils/theme/widget_themes/custom_decoration.dart';
import '../../../../../utils/validators/validation.dart';

class CustomerForm extends StatelessWidget {
  final MonitorController controller;

  const CustomerForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller.customerName,
            decoration: CustomDecoration.uInputDecoration(labelText: 'Customer Name'),
            onChanged: (value) => controller.onSearchCustomer(value),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.address,
                decoration: CustomDecoration.uInputDecoration(labelText: 'Address'),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: TextFormField(
                controller: controller.phone,
                validator: (value) => UValidator.validatePhoneNumber(value),
                decoration: CustomDecoration.uInputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
      ],
    );
  }
}