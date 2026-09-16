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
        horizontal: 24,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 760,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        controller.clearForm();
                        Get.back();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _TextField(
                  controller: controller.nameController,
                  label: 'Name',
                  required: true,
                ),
                const SizedBox(height: 10),
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
                    const SizedBox(width: 10),
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
                const SizedBox(height: 10),
                _TextField(
                  controller: controller.descriptionController,
                  label: 'Description',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DropdownField<String>(
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
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () {
                              controller.clearForm();
                              Get.back();
                            },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () async {
                              final saved = await controller.saveService();

                              if (saved && context.mounted) {
                                controller.clearForm();
                                Get.back();
                              }
                            },
                      child: controller.isLoading.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              controller.isEditMode.value
                                  ? 'Update'
                                  : 'Save',
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _unitLabel(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static String _statusLabel(String value) {
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
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
      ),
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
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
      ),
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
