import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../controller/home_controller.dart';

class DashboardFilterBar extends StatelessWidget {
  const DashboardFilterBar({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final vehicleValue = controller.vehicles.any(
      (v) => v.id == controller.selectedVehicleId.value,
    )
        ? controller.selectedVehicleId.value
        : 'all';

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _DashboardDropdown(
            icon: Iconsax.truck,
            child: DropdownButton<String>(
              value: vehicleValue,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text(
                    'All Assigned Vehicles',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...controller.vehicles.map(
                  (v) => DropdownMenuItem(
                    value: v.id,
                    child: Text(
                      '${v.number} • ${v.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: controller.setSelectedVehicle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _DashboardDropdown(
            icon: Iconsax.calendar_1,
            child: DropdownButton<String>(
              value: controller.selectedPeriod.value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              items: controller.periodOptions
                  .map(
                    (period) => DropdownMenuItem(
                      value: period,
                      child: Text(period),
                    ),
                  )
                  .toList(),
              onChanged: controller.setSelectedPeriod,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardDropdown extends StatelessWidget {
  const _DashboardDropdown({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF1B5E20)),
          const SizedBox(width: 7),
          Expanded(child: child),
        ],
      ),
    );
  }
}
