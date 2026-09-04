import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/utils/helper/helper_functions.dart';
import 'package:krishi_karobar/features/recent_activity/controllers/activity_controller.dart';

class FilterForm extends StatelessWidget {
  final ActivityController controller;

  const FilterForm({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Advanced Filter'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 1. Date Range Section ---
              _buildSectionTitle('Date Range'),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.date_range)),
                items: controller.filterOptions.map((String option) {
                  return DropdownMenuItem<String>(value: option, child: Text(option));
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) controller.setFilter(newValue);
                },
              ),
              if (controller.selectedFilter.value == 'Custom') ...[
                const SizedBox(height: 8),
                UHelperFunctions.datePicker(
                  label: 'Start Date',
                  context: context,
                  controller: controller.filterStartDate,
                ),
                const SizedBox(height: 8),
                UHelperFunctions.datePicker(
                  label: 'End Date',
                  context: context,
                  controller: controller.filterEndDate,
                ),
              ],

              const Divider(height: 32),

              // --- 2. Vehicles Multi-Select ---
              _buildMultiSelectSection(
                title: 'Vehicles',
                icon: Icons.directions_car,
                items: controller.vehicles.map((v) => _MultiSelectItem(id: v.guid, label: v.number)).toList(),
                selectedIds: controller.selectedVehicleGuids,
              ),

              const Divider(height: 32),

              // --- 3. Staff Multi-Select ---
              _buildMultiSelectSection(
                title: 'User Created By (Staff)',
                icon: Icons.person,
                items: controller.users.map((s) => _MultiSelectItem(id: s.guid, label: s.fullname)).toList(),
                selectedIds: controller.selectedStaffGuids,
              ),

              const Divider(height: 32),

              // --- 4. Customers Multi-Select ---
              _buildMultiSelectSection(
                title: 'Customers',
                icon: Icons.people_outline,
                items: controller.customers.map((c) => _MultiSelectItem(id: c.guid, label: c.name)).toList(),
                selectedIds: controller.selectedCustomerGuids,
              ),

            ],
          )),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            controller.clearFilter();
            Navigator.pop(context);
          },
          child: const Text('Reset All'),
        ),
        ElevatedButton(
          onPressed: () {
            controller.syncWithFirebase();
            Navigator.pop(context);
          },
          child: const Text('Apply Filter'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ),
    );
  }

  Widget _buildMultiSelectSection({
    required String title,
    required IconData icon,
    required List<_MultiSelectItem> items,
    required RxList<String> selectedIds,
  }) {
    return ExpansionTile(
      leading: Icon(icon),
      title: Text('$title (${selectedIds.length})'),
      subtitle: Text(
        selectedIds.isEmpty ? 'All selected' : 'Selected: ${selectedIds.length}',
        style: const TextStyle(fontSize: 12),
      ),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return CheckboxListTile(
                title: Text(item.label),
                value: selectedIds.contains(item.id),
                dense: true,
                onChanged: (bool? checked) {
                  if (checked == true) {
                    selectedIds.add(item.id);
                  } else {
                    selectedIds.remove(item.id);
                  }
                  controller.applyLocalFilters();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MultiSelectItem {
  final String id;
  final String label;
  _MultiSelectItem({required this.id, required this.label});
}
