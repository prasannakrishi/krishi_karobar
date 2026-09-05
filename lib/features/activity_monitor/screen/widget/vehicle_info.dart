import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/monitor_controller.dart';

class VehicleInfo extends StatelessWidget {
  const VehicleInfo({super.key, required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VehicleSelector(controller: controller),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.vehicleName,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Vehicle'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller.vehicleOwner,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Owner'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller.driver,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Driver'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller.supervisor,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Supervisor'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleSelector extends StatelessWidget {
  const _VehicleSelector({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controller.vehicleSearch,
          decoration: InputDecoration(
            labelText: 'Vehicle Number',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: controller.openVehicleSearch,
            ),
          ),
          onTap: controller.openVehicleSearch,
          onChanged: controller.onSearchVehicle,
        ),
        Obx(() {
          if (!controller.showVehicleSuggestions.value) {
            return const SizedBox.shrink();
          }

          return _SuggestionList(
            children: controller.filteredVehicles
                .map(
                  (vehicle) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(vehicle.number),
                    subtitle: Text(vehicle.name),
                    onTap: () {
                      controller.vehicleSearch.text = vehicle.number;
                      controller.selectVehicle(vehicle);
                    },
                  ),
                )
                .toList(),
          );
        }),
      ],
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('No matching vehicle found'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: children,
        ),
      ),
    );
  }
}
