import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:krishi_karobar/models/models.dart';
import '../../controller/vehicle_controller.dart';

class VehicleForm extends StatelessWidget {
  const VehicleForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VehicleController>();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                              ? controller.editingVehicle?.number ?? 'Vehicle'
                              : 'New Vehicle',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          controller.clearVehicle();
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
                          controller: controller.vNumberController,
                          label: 'Vehicle Number',
                          required: true,
                          fieldKey: 'vehicleNumber',
                          capitalization: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DropdownField<String>(
                          label: 'Vehicle Type',
                          value: controller.vTypeController.text.isEmpty
                              ? null
                              : controller.vTypeController.text,
                          items: controller.vehicleTypes.toList(),
                          required: true,
                          warning:
                              controller.warningField.value == 'vehicleType',
                          onChanged: (value) {
                            controller.vTypeController.text = value ?? '';
                            if (value != null) {
                              controller.warningField.value = null;
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
                          controller: controller.vNameController,
                          label: 'Vehicle Name',
                          required: true,
                          fieldKey: 'vehicleName',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TextField(
                          controller: controller.vModelController,
                          label: 'Model Year',
                          required: true,
                          fieldKey: 'modelYear',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Divider(),
                  const SizedBox(height: 5),
                  _UserDropdown(
                    label: 'Owner',
                    value: controller.selectedOwner.value,
                    users: controller.vehicleOwners.toList(),
                    required: true,
                    warning: controller.warningField.value == 'owner',
                    onChanged: controller.selectOwner,
                  ),
                  const SizedBox(height: 8),
                  _SupportedServices(
                    services: controller.services.where((s) {
                      final selectedVType = controller.vTypeController.text
                          .trim()
                          .toLowerCase();
                      final rawSType =
                          (s.vehicleType as dynamic)?.toString() ?? 'All';
                      final serviceVType = rawSType.trim().toLowerCase();
                      return selectedVType.isEmpty ||
                          serviceVType.isEmpty ||
                          serviceVType == 'all' ||
                          serviceVType == selectedVType;
                    }).toList(),
                    selectedServiceIds: controller.selectedServiceIds.toList(),
                    warning: controller.warningField.value == 'services',
                    onToggle: controller.toggleService,
                  ),
                  const SizedBox(height: 8),
                  _TextField(
                    controller: controller.vNotesController,
                    label: 'Notes (Optional)',
                    maxLines: 1,
                    fieldKey: 'vehicleNote',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () {
                            Navigator.of(context).pop();
                            controller.clearVehicle();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.grey),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () async {
                            final saved = await controller.saveVehicle();
                            if (saved && context.mounted) {
                              Navigator.of(context).pop();
                              controller.clearVehicle();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.green,
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
                              fontWeight: FontWeight.bold,
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
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? fieldKey;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;

  const _TextField({
    required this.controller,
    required this.label,
    this.fieldKey,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final vehicleController = Get.find<VehicleController>();

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return Obx(
          () => TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            onChanged: (_) {
              if (fieldKey != null &&
                  vehicleController.warningField.value == fieldKey) {
                vehicleController.warningField.value = null;
              }
            },
            decoration: _inputDecoration(
              required ? '$label *' : label,
              hasValue: value.text.trim().isNotEmpty,
              warning: vehicleController.warningField.value == fieldKey,
            ),
          ),
        );
      },
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item)? itemLabel;
  final ValueChanged<T?> onChanged;
  final bool required;
  final bool warning;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.required = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(10),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      decoration: _inputDecoration(
        required ? '$label *' : label,
        hasValue: value != null,
        warning: warning,
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            itemLabel?.call(item) ?? item.toString(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

/// Dropdown of users, already filtered by role (owners vs. drivers) by the
/// controller. Picking a user here is what assigns them to the vehicle in
/// that role.
class _UserDropdown extends StatelessWidget {
  final String label;
  final UserModel? value;
  final List<UserModel> users;
  final ValueChanged<UserModel?> onChanged;
  final bool required;
  final bool warning;

  const _UserDropdown({
    required this.label,
    required this.value,
    required this.users,
    required this.onChanged,
    this.required = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final containsValue = value != null && users.any((u) => u.id == value!.id);

    return DropdownButtonFormField<String>(
      initialValue: containsValue ? value!.id : null,
      isExpanded: true,
      borderRadius: BorderRadius.circular(10),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      decoration: _inputDecoration(
        required ? '$label *' : label,
        hasValue: value != null,
        warning: warning,
      ),
      items: [
        ...users.map(
          (user) => DropdownMenuItem<String>(
            value: user.id,
            child: Text(user.fullname, overflow: TextOverflow.ellipsis),
          ),
        ),
        // Keep the currently assigned user selectable even if they've since
        // fallen out of the role-filtered list (e.g. while editing).
        if (value != null && !containsValue)
          DropdownMenuItem<String>(
            value: value!.id,
            child: Text(value!.fullname, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id == null || id.isEmpty) {
          onChanged(null);
        } else {
          onChanged(
            users.firstWhereOrNull((user) => user.id == id) ??
                (value?.id == id ? value : null),
          );
        }
      },
    );
  }
}

class _SupportedServices extends StatelessWidget {
  final List<ServiceModel> services;
  final List<String> selectedServiceIds;
  final ValueChanged<String> onToggle;
  final bool warning;

  const _SupportedServices({
    required this.services,
    required this.selectedServiceIds,
    required this.onToggle,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedServices = services
        .where((service) => selectedServiceIds.contains(service.id))
        .toList();

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showServiceSelector(context),
      child: InputDecorator(
        decoration:
            _inputDecoration(
              'Supported Services *',
              hasValue: selectedServiceIds.isNotEmpty,
              warning: warning,
            ).copyWith(
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
              ),
            ),
        child: selectedServices.isEmpty
            ? const Text(
                'Select supported services',
                style: TextStyle(color: Colors.grey),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: selectedServices.map((service) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(service.name),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => onToggle(service.id),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }

  void _showServiceSelector(BuildContext context) {
    final vehicleController = Get.find<VehicleController>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Obx(() {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Supported Services',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: services.map((service) {
                        final selected = vehicleController.selectedServiceIds
                            .contains(service.id);
                        return CheckboxListTile(
                          dense: true,
                          value: selected,
                          title: Text(service.name),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) {
                            onToggle(service.id);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

InputDecoration _inputDecoration(
  String label, {
  bool hasValue = false,
  bool warning = false,
}) {
  final Color borderColor;
  if (warning) {
    borderColor = Colors.red;
  } else if (hasValue) {
    borderColor = Colors.green;
  } else {
    borderColor = Colors.grey.shade400;
  }

  return InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor, width: 1.5),
    ),
  );
}
