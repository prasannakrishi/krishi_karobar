import 'package:flutter/material.dart';

import '../../controllers/monitor_controller.dart';
import '../../../../../common/widgets/customer_search_field.dart';

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
          showExtraFields: true,
          onCustomerSelected: (customer) {
            controller.selectCustomer(customer);
          },
        ),
      ],
    );
  }
}
