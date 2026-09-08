import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/models/models.dart';
import '../../controller/vehicle_controller.dart';

class VehiclesForm extends StatelessWidget {
  const VehiclesForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VehicleController>();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _TextField(controller: controller.vNumberController, label: 'Vehicle Number', required: true, fieldKey: 'vehicleNumber', capitalization: TextCapitalization.characters)),
            const SizedBox(width: 6),
            Expanded(
              child: Obx(
                    () => _DropdownField<String>(
                  label: 'Vehicle Type',
                  value: controller.vTypeController.text.isEmpty ? null : controller.vTypeController.text,
                  items: controller.vehicleTypes.toList(),
                  required: true,
                  warning: controller.warningField.value == 'vehicleType',
                  onChanged: (value) {
                    controller.vTypeController.text = value ?? '';
                    if (value != null) controller.warningField.value = null;
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _TextField(controller: controller.vNameController, label: 'Vehicle Name', required: true, fieldKey: 'vehicleName')),
            const SizedBox(width: 6),
            Expanded(child: _TextField(controller: controller.vModelController, label: 'Model Year', required: true, fieldKey: 'modelYear', keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Obx(
                    () => _DropdownField<UserModel>(
                  label: 'Owner',
                  value: controller.selectedOwner.value,
                  items: controller.filteredOwners.toList(),
                  itemLabel: (user) => user.fullname,
                  required: true,
                  warning: controller.warningField.value == 'owner',
                  onChanged: (user) {
                    controller.selectedOwner.value = user;
                    if (user != null) controller.warningField.value = null;
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Obx(
                    () => _UserDropdown(
                  label: 'Driver',
                  value: controller.selectedDriver.value,
                  users: controller.drivers.toList(),
                  onChanged: (user) => controller.selectedDriver.value = user,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Obx(
              () => _SupportedServices(
            services: controller.services.toList(),
            selectedServiceIds: controller.selectedServiceIds.toList(),
            warning: controller.warningField.value == 'services',
            onToggle: controller.toggleService,
          ),
        ),
        const SizedBox(height: 8),
        _TextField(controller: controller.vNotesController, label: 'Notes (Optional)', maxLines: 2),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  controller.clearVehicle();
                  Get.back();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Obx(
                    () => ElevatedButton(
                  onPressed: controller.isLoading.value ? null : controller.saveVehicle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.green.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: controller.isLoading.value
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
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
      builder: (_, value, __) {
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
              label,
              required: required,
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
      decoration: _inputDecoration(label, required: required, hasValue: value != null, warning: warning),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(itemLabel?.call(item) ?? item.toString(), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _UserDropdown extends StatelessWidget {
  final String label;
  final UserModel? value;
  final List<UserModel> users;
  final ValueChanged<UserModel?> onChanged;

  const _UserDropdown({
    required this.label,
    required this.value,
    required this.users,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value?.id,
      isExpanded: true,
      borderRadius: BorderRadius.circular(10),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      decoration: _inputDecoration(label, hasValue: value != null),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('Not Assigned', style: TextStyle(color: Colors.grey)),
        ),
        ...users.map(
              (user) => DropdownMenuItem<String>(
            value: user.id,
            child: Text(user.fullname, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (id) {
        if (id == null || id.isEmpty) {
          onChanged(null);
        } else {
          onChanged(users.firstWhereOrNull((user) => user.id == id));
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
    final selectedServices = services.where((service) => selectedServiceIds.contains(service.id)).toList();

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showServiceSelector(context),
      child: InputDecorator(
        decoration: _inputDecoration(
          'Supported Services',
          required: true,
          hasValue: selectedServiceIds.isNotEmpty,
          warning: warning,
        ).copyWith(
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ),
        child: selectedServices.isEmpty
            ? const Text('Select supported services', style: TextStyle(color: Colors.grey))
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Supported Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: services.map((service) {
                          final selected = selectedServiceIds.contains(service.id);
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            title: Text(service.name),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (_) {
                              onToggle(service.id);
                              setState(() {});
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
            },
          ),
        );
      },
    );
  }
}

InputDecoration _inputDecoration(
    String label, {
      bool required = false,
      bool hasValue = false,
      bool warning = false,
    }) {
  final Color borderColor;
  if (warning) {
    borderColor = Colors.red;
  } else if (hasValue) {
    borderColor = Colors.green;
  } else if (required) {
    borderColor = Colors.amber.shade300;
  } else {
    borderColor = Colors.grey.shade400;
  }

  return InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor, width: 1.5),
    ),
  );
}