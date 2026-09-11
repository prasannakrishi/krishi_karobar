import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../models/service_model.dart';
import '../../controllers/monitor_controller.dart';

class ActivityForm extends StatelessWidget {
  const ActivityForm({super.key, required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final timer = controller.timerController;

    return Column(
      children: [
        // Service and Rate
        Row(
          children: [
            Expanded(
              child: _ServiceSelector(controller: controller),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: controller.rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'),),
                ],
                decoration: const InputDecoration(
                  labelText: 'Rate / Hour',
                  prefixText: 'Rs. ',
                ),
              ),
            ),

          ],
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: controller.description,
          maxLines: 1,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 10),
        // Start and End Time
        Obx(
              () => Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey(timer.startTimeText.value),
                  initialValue: timer.startTimeText.value,
                  readOnly: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  decoration: const InputDecoration(
                    labelText: 'Start Time',
                    contentPadding: EdgeInsets.all(8)
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: ValueKey(timer.endTimeText.value),
                  initialValue: timer.endTimeText.value,
                  readOnly: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  decoration: const InputDecoration(
                    labelText: 'End Time',
                    contentPadding: EdgeInsets.all(8)
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Row(
            children: [
              Expanded(child:
                _InfoCard(
                  title: 'DURATION',
                  value: timer.duration.value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child:
              _InfoCard(
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
    return Obx(() => DropdownButtonFormField<ServiceModel>(
      initialValue: controller.selectedService.value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Service'),
      hint: Text(controller.selectedVehicle.value == null? 'Select vehicle first'
          : 'Select service'),
      items: controller.supportedServices
          .map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
      onChanged: controller.selectedVehicle.value == null
          ? null
          : (service) {
        if (service != null) {
          controller.selectService(service);
        }
      },
    ));
  }
}

class _InfoCard extends StatelessWidget {

  final String title;
  final String value;

  const _InfoCard({
    required this.title,
    required this.value,
  });


  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
