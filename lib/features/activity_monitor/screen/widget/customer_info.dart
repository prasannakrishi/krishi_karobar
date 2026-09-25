import 'package:flutter/material.dart';

import '../../controllers/monitor_controller.dart';
import '../../../../../common/widgets/customer_search_field.dart';
import '../../../../../utils/validators/validation.dart';

class CustomerForm extends StatelessWidget {
  const CustomerForm({super.key, required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomerSearchField(
          nameController: controller.customerName,
          phoneController: controller.phone,
          addressController: controller.address,
          isCustomDecoration: false,
          onCustomerSelected: (customer) {
            controller.selectCustomer(customer);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.address,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller.phone,
                keyboardType: TextInputType.phone,
                validator: UValidator.validatePhoneNumber,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                onChanged: (_) => controller.onCustomerChanged(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
