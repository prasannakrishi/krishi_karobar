import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
import '../../controller/user_controller.dart';

class UserForm extends StatelessWidget {
  const UserForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UserController>();

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
                            ? controller.editingUser?.fullname ?? 'User'
                            : 'New User',
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
                        controller: controller.phoneController,
                        label: 'Phone',
                        required: true,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TextField(
                        controller: controller.addressController,
                        label: 'Address',
                        required: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TextField(
                  controller: controller.emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DropdownField<String>(
                        label: 'User Type',
                        value: controller.selectedUserType.value,
                        items: UserTypes.values,
                        itemLabel: _userTypeLabel,
                        onChanged: controller.onUserTypeChanged,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RolesField(controller: controller),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _VehicleField(controller: controller),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DropdownField<String>(
                        label: 'User Status',
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
                        final saved =
                        await controller.saveUser();

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

  static String _userTypeLabel(String value) {
    switch (value) {
      case UserTypes.organization:
        return 'Organization';
      case UserTypes.external:
        return 'External';
      case UserTypes.guest:
        return 'Guest';
      default:
        return value;
    }
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
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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

class _RolesField extends StatelessWidget {
  const _RolesField({
    required this.controller,
  });

  final UserController controller;

  @override
  Widget build(BuildContext context) {
    final guest =
        controller.selectedUserType.value == UserTypes.guest;

    return InkWell(
      onTap: guest
          ? null
          : () => _showRolesDialog(context, controller),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Roles',
          enabled: !guest,
        ),
        child: Text(
          guest
              ? 'Not applicable'
              : controller.selectedRoles.isEmpty
              ? 'Select Roles'
              : controller.selectedRoles
              .map(_formatRole)
              .join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showRolesDialog(
      BuildContext context,
      UserController controller,
      ) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Select Roles'),
          content: Obx(
                () => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: UserRoles.values.map(
                      (role) {
                    return CheckboxListTile(
                      dense: true,
                      value: controller.selectedRoles.contains(role),
                      title: Text(_formatRole(role)),
                      onChanged: (_) => controller.toggleRole(role),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  static String _formatRole(String value) {
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1)}',
    )
        .join(' ');
  }
}

class _VehicleField extends StatelessWidget {
  const _VehicleField({
    required this.controller,
  });

  final UserController controller;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.showVehicleAssignment;
    final selectedVehicles = enabled
        ? controller.vehicles
        .where((v) => controller.selectedVehicleIds.contains(v.id))
        .toList()
        : <VehicleModel>[];

    return InkWell(
      onTap: enabled ? () => _showVehiclePicker(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Assigned Vehicles',
          enabled: enabled,
          suffixIcon: enabled
              ? const Icon(Icons.keyboard_arrow_down_rounded, size: 20)
              : null,
        ),
        child: !enabled
            ? const Text(
          'Not applicable',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        )
            : selectedVehicles.isEmpty
            ? const Text(
          'Select vehicles',
          style: TextStyle(color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        )
            : Wrap(
          spacing: 6,
          runSpacing: 4,
          children: selectedVehicles
              .map(
                (v) => Chip(
              label: Text(v.number),
              materialTapTargetSize:
              MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onDeleted: () =>
                  controller.toggleVehicleAssignment(v.id),
            ),
          )
              .toList(),
        ),
      ),
    );
  }

  void _showVehiclePicker(BuildContext context) {
    final vehicles = controller.vehicles;

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
                    const Text(
                      'Assigned Vehicles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height:4),
                    Flexible(
                      child: vehicles.isEmpty
                          ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No registered vehicle found'),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: vehicles.length,
                        itemBuilder: (_, index) {
                          final vehicle = vehicles[index];
                          final selected = controller
                              .selectedVehicleIds
                              .contains(vehicle.id);

                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            controlAffinity:
                            ListTileControlAffinity.leading,
                            title: Text(
                              '${vehicle.uId} • ${vehicle.name}',
                            ),
                            subtitle: Text(vehicle.number),
                            onChanged: (_) {
                              controller.toggleVehicleAssignment(
                                vehicle.id,
                              );
                              setState(() {});
                            },
                          );
                        },
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