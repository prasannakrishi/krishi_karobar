import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../controllers/monitor_controller.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';

class ActivityForm extends StatelessWidget {
  final MonitorController controller;

  const ActivityForm({super.key,required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          // Activity Details Section
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: controller.rate,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ FilteringTextInputFormatter.digitsOnly,],
                  decoration: CustomDecoration.uInputDecoration(labelText:'Rate/hour',prefixText: 'रु ',),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: controller.serviceType,
                  decoration: CustomDecoration.uInputDecoration(labelText: 'Service Type'),
                  readOnly: true,
                  onTap: controller.onSearchService,
                )
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.description,
            maxLines: 1,
            decoration: CustomDecoration.uInputDecoration(labelText: 'Description').copyWith(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Strt Time  End time
          Row(
            children: [
              Expanded(
                child: CustomDecoration.buildReadOnlyField(
                  label: 'Start Time',
                  valueNotifier: controller.timeController.startTimeNotifier,
                  alignment: TextAlign.center,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: CustomDecoration.buildReadOnlyField(
                  label: 'End Time',
                  valueNotifier: controller.timeController.endTimeNotifier,
                  alignment: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Duration and Amount
          Row(
            children: [
              Expanded(child: CustomDecoration.buildMetricCard(
                  'DURATION', controller.timeController.durationNotifier, '00:00:00'),
              ),
              const SizedBox(width: 5),
              Expanded(child: CustomDecoration.buildMetricCard('AMOUNT', controller.timeController.amountNotifier, 'रु 0',
                  prefix: 'रु '),
              ),
              const SizedBox(width: 5),
            ],
          ),
        ]
      ),
    );
  }
}