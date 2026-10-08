import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/common/widgets/customer_search_field.dart';
import 'package:krishi_karobar/features/controllers.dart';

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
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : controller.saveCustomer,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: controller.isLoading.value ?
                    const SizedBox(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey,
                      ),
                    )
                    : Text(
                        controller.isEditMode.value ? 'Update Customer' : 'Save Customer',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ),
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }
}
