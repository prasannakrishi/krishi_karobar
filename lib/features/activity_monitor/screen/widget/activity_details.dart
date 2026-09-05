import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/monitor_controller.dart';

class ActivityForm extends StatelessWidget {
  const ActivityForm({super.key, required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final timer = controller.timerController;

    return Column(
      children: [
        _ServiceSelector(controller: controller),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller.rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Rate / Hour',
            prefixText: 'Rs. ',
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller.description,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 10),
        Obx(
          () => Row(
            children: [
              Expanded(
                child: _InfoCard(
                  title: 'START TIME',
                  value: timer.startTimeText.value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoCard(
                  title: 'END TIME',
                  value: timer.endTimeText.value,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Row(
            children: [
              Expanded(
                child: _InfoCard(
                  title: 'DURATION',
                  value: timer.duration.value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoCard(
                  title: 'AMOUNT',
                  value: 'Rs. ${timer.amount.value.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceSelector extends StatelessWidget {
  const _ServiceSelector({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Obx(
          () => TextFormField(
            controller: controller.serviceSearch,
            readOnly: controller.selectedVehicle.value == null,
            decoration: InputDecoration(
              labelText: 'Service',
              hintText: controller.selectedVehicle.value == null
                  ? 'Select vehicle first'
                  : 'Search service',
              suffixIcon: const Icon(Icons.search),
            ),
            onTap: controller.openServiceSearch,
            onChanged: controller.onSearchService,
          ),
        ),
        Obx(() {
          if (!controller.showServiceSuggestions.value) {
            return const SizedBox.shrink();
          }

          return Card(
            margin: const EdgeInsets.only(top: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: controller.filteredServices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No supported service found'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: controller.filteredServices.length,
                      itemBuilder: (_, index) {
                        final service = controller.filteredServices[index];

                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.build_outlined),
                          title: Text(service.name),
                          subtitle: Text(
                            'Rs. ${service.rate.toStringAsFixed(0)} / hour',
                          ),
                          onTap: () => controller.selectService(service),
                        );
                      },
                    ),
            ),
          );
        }),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
