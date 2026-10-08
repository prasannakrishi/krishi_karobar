import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../common/widgets/customer_search_field.dart';
import '../../../../common/widgets/u_widgets.dart';
import '../../../controllers.dart';

class CustomerForm extends StatelessWidget {
  const CustomerForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CustomerController.instance;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: SingleChildScrollView(
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.isEditMode.value
                              ? controller.editingCustomer?.name ?? 'Customer'
                              : 'New Customer',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          controller.clearSelection();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomerSearchField(
                    nameController: controller.nameController,
                    phoneController: controller.phoneController,
                    addressController: controller.addressController,
                    onCustomerSelected: (customer) {
                      controller.phoneController.text = customer.phone ?? '';
                      controller.addressController.text = customer.address;
                    },
                  ),
                  const SizedBox(height: 18),
                  UButton(
                    text: controller.isEditMode.value ? 'Update Customer' : 'Save Customer',
                    style: UButtonStyle.primary,
                    isFullWidth: true,
                    isLoading: controller.isLoading.value,
                    onPressed: controller.saveCustomer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
