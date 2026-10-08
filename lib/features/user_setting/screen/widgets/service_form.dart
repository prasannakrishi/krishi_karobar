import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/widgets/u_widgets.dart';
import '../../controller/service_controller.dart';

class ServiceForm extends StatelessWidget {
  const ServiceForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ServiceController>();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 16,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 760,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                              ? controller.editingService?.name ?? 'Service'
                              : 'New Service',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          controller.clearForm();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: UTextField(
                          controller: controller.nameController,
                          labelText: 'Name',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: UOptionField<String>(
                          labelText: 'Vehicle Type',
                          value: controller.selectedVehicleType.value,
                          options: ServiceController.vehicleTypes
                              .map((v) => UOption<String>(value: v, label: v))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              controller.selectedVehicleType.value = value;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: UNumberField(
                          controller: controller.rateController,
                          labelText: 'Rate',
                          required: true,
                          isDecimal: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: UOptionField<String>(
                          labelText: 'Unit',
                          value: controller.selectedUnit.value,
                          options: ServiceController.units
                              .map((u) => UOption<String>(value: u, label: _unitLabel(u)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              controller.selectedUnit.value = value;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  UTextField(
                    controller: controller.descriptionController,
                    labelText: 'Description',
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  UOptionField<String>(
                    labelText: 'Status',
                    value: controller.selectedStatus.value,
                    options: const [
                      UOption(value: 'active', label: 'Active'),
                      UOption(value: 'inactive', label: 'Inactive'),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.selectedStatus.value = value;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: UButton(
                          text: 'Cancel',
                          style: UButtonStyle.outline,
                          onPressed: controller.isLoading.value
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  controller.clearForm();
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: UButton(
                          text: controller.isEditMode.value ? 'Update' : 'Save',
                          style: UButtonStyle.primary,
                          isLoading: controller.isLoading.value,
                          onPressed: () async {
                            final saved = await controller.saveService();
                            if (saved && context.mounted) {
                              Navigator.of(context).pop();
                              controller.clearForm();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _unitLabel(String? value) {
    if (value == null || value.isEmpty) return 'Hour';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
