import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/features/controllers.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';

class CustomerForm extends StatelessWidget {
  final controller = Get.find<CustomerController>();


  Widget build(BuildContext context) {
    final controller = CustomerController.instance;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
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
                TextFormField(
                  controller: controller.nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: CustomDecoration.uInputDecoration(
                    labelText: 'Customer Name *',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: controller.phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: CustomDecoration.uInputDecoration(
                    labelText: 'Phone Number',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: controller.addressController,
                  textCapitalization: TextCapitalization.words,
                  maxLines: 1,
                  decoration: CustomDecoration.uInputDecoration(
                    labelText: 'Address',
                  ),
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
                    )
                ),
              ]
            )),
          ),
        ),
      )
    );
  }
}
