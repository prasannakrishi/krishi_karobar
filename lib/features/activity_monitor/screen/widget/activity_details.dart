import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8), // समान padding
          child: Row(
            children: [
              Expanded(
                child: _ServiceSelector(controller: controller),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _DescriptionAutocomplete(controller: controller),
        ),
        const SizedBox(height: 10),

        // Start and End Time
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: timer.startTimeController,
                  readOnly: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  decoration: const InputDecoration(
                    labelText: 'Start Time',
                    contentPadding: EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: timer.endTimeController,
                  readOnly: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  decoration: const InputDecoration(
                    labelText: 'End Time',
                    contentPadding: EdgeInsets.all(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Obx(
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
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Obx(() {
            final activity = controller.liveActivity;
            if (activity == null) return const SizedBox.shrink();

            final isPaused = activity.status == ActivityStatus.paused;

            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (isPaused ? Colors.orange : Colors.green).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPaused ? Colors.orange : Colors.green,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPaused ? Icons.pause_circle : Icons.play_circle,
                      color: isPaused ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${isPaused ? 'PAUSED' : 'RUNNING'} · Started by '
                            '${controller.startedByName(activity)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );

  }
}

class _DescriptionAutocomplete extends StatefulWidget {
  const _DescriptionAutocomplete({required this.controller});

  final MonitorController controller;

  @override
  State<_DescriptionAutocomplete> createState() =>
      _DescriptionAutocompleteState();
}

class _DescriptionAutocompleteState extends State<_DescriptionAutocomplete> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      focusNode: _focusNode,
      textEditingController: widget.controller.description,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final suggestions = widget.controller.recentDescriptions;
        final query = textEditingValue.text.trim().toLowerCase();

        if (query.isEmpty) {
          return suggestions;
        }

        return suggestions.where(
          (desc) => desc.toLowerCase().contains(query),
        );
      },
      onSelected: (String selection) {
        widget.controller.description.text = selection;
        widget.controller.description.selection = TextSelection.collapsed(
          offset: selection.length,
        );
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          maxLines: 1,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'Type or select previous description',
            suffixIcon: PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down),
              tooltip: 'Previous Descriptions',
              onSelected: (String value) {
                widget.controller.description.text = value;
                widget.controller.description.selection =
                    TextSelection.collapsed(offset: value.length);
              },
              itemBuilder: (BuildContext context) {
                final suggestions = widget.controller.recentDescriptions;
                if (suggestions.isEmpty) {
                  return const [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text('No previous descriptions found'),
                    ),
                  ];
                }
                return suggestions.map((desc) {
                  return PopupMenuItem<String>(
                    value: desc,
                    child: Text(desc),
                  );
                }).toList();
              },
            ),
          ),
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
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
          hint: Text(controller.selectedVehicle.value == null
              ? 'Select vehicle first'
              : 'Select service'),
          items: controller.supportedServices
              .map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
          onChanged: controller.selectedVehicle.value == null ||
                  (controller.liveActivity != null && !controller.isController)? null
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
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
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
