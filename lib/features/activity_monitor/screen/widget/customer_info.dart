import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/monitor_controller.dart';
import '../../../../../utils/validators/validation.dart';

class CustomerForm extends StatelessWidget {
  const CustomerForm({super.key, required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controller.customerName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Customer Name',
            suffixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            controller.onCustomerChanged();
            controller.onSearchCustomer(value);
          },
        ),
        Obx(() {
          if (!controller.showCustomerSuggestions.value) {
            return const SizedBox.shrink();
          }

          return Card(
            margin: const EdgeInsets.only(top: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: controller.filteredCustomers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No matching customer found'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: controller.filteredCustomers.length,
                      itemBuilder: (_, index) {
                        final customer = controller.filteredCustomers[index];

                        return InkWell(
                          onTap: () => controller.selectCustomer(customer),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        customer.phone,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (customer.address.isNotEmpty)
                                  Text(
                                    customer.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          );
        }),
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
