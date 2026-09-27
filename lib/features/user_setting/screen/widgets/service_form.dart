import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          controller: controller.nameController,
                          label: 'Name',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DropdownField<String>(
                          label: 'Vehicle Type',
                          value: controller.selectedVehicleType.value,
                          items: ServiceController.vehicleTypes,
                          itemLabel: (v) => v ?? 'All',
                          onChanged: (value) {
                            if (value != null) {
                              controller.selectedVehicleType.value = value;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          controller: controller.rateController,
                          label: 'Rate',
                          required: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DropdownField<String>(
                          label: 'Unit',
                          value: controller.selectedUnit.value,
                          items: ServiceController.units,
                          itemLabel: _unitLabel,
                          onChanged: (value) {
                            if (value != null) {
                              controller.selectedUnit.value = value;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _TextField(
                    controller: controller.descriptionController,
                    label: 'Description',
                    maxLines: 1,
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 8),
                  _DropdownField<String>(
                    label: 'Status',
                    value: controller.selectedStatus.value,
                    items: const [
                      'active',
                      'inactive',
                    ],
                    itemLabel: _statusLabel,
                    onChanged: (value) {
                      if (value != null) {
                        controller.selectedStatus.value = value;
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () {
                            Navigator.of(context).pop();
                            controller.clearForm();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent, width: 1.2),
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () async {
                            final saved = await controller.saveService();
                            if (saved && context.mounted) {
                              Navigator.of(context).pop();
                              controller.clearForm();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: controller.isLoading.value
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            controller.isEditMode.value ? 'Update' : 'Save',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
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

  static String _statusLabel(String? value) {
    return value == 'active' ? 'Active' : 'Inactive';
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.required = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _inputDecoration(required ? '$label *' : label),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T? value) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final containsValue = value != null && items.contains(value);
    final initial = containsValue ? value : (items.isNotEmpty ? items.first : null);

    return DropdownButtonFormField<T>(
      initialValue: initial,
      isExpanded: true,
      borderRadius: BorderRadius.circular(10),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      decoration: _inputDecoration(label),
      items: items.map(
        (item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              itemLabel(item),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ).toList(),
      onChanged: onChanged,
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.green, width: 1.5),
    ),
  );
}
