import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
import '../../../../services/data_cache_service.dart';
import '../../../../utils/theme/widget_themes/custom_decoration.dart';
import '../../../payment/screen/widgets/payment_dialog.dart';
import '../../controllers/activity_controller.dart';

class DetailsCardForm extends StatefulWidget {
  const DetailsCardForm({
    super.key,
    required this.entry,
    required this.controller,
  });

  final ActivityModel entry;
  final ActivityController controller;

  @override
  State<DetailsCardForm> createState() =>
      _DetailsCardFormState();
}

class _DetailsCardFormState
    extends State<DetailsCardForm> {
  late TextEditingController descriptionController;

  final FocusNode _descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    descriptionController = TextEditingController(
      text: widget.entry.description ?? '',
    );

    _descriptionFocusNode.addListener(() {
      if (!_descriptionFocusNode.hasFocus) {
        _saveDescription();
      }
    });
  }

  @override
  void didUpdateWidget(
      DetailsCardForm oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.entry.id != widget.entry.id) {
      descriptionController.text =
          widget.entry.description ?? '';
    }
  }

  Future<void> _saveDescription() async {
    final value = descriptionController.text.trim();

    if (value == (widget.entry.description ?? '')) {
      return;
    }

    await widget.controller.updateDescription(
      widget.entry,
      value,
    );
  }

  void _openPayment() {
    Get.dialog(
      PaymentDialog(
        customerId: widget.entry.customerId,
      ),
    );
  }

  @override
  void dispose() {
    descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cache = DataCacheService.instance;

    final vehicle =
    cache.vehicles[widget.entry.vehicleId];

    final customer =
    cache.customers[widget.entry.customerId];

    final service =
    cache.services[widget.entry.serviceId];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color.fromARGB(
        255,
        228,
        247,
        248,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            _buildBasicInfo(
              vehicle?.number ?? '-',
              customer?.name ?? '-',
            ),
            const SizedBox(height: 8),
            _buildServiceInfo(
              service?.name ?? '-',
              widget.entry.rate,
            ),
            const SizedBox(height: 8),
            _buildTimeInfo(),
            const SizedBox(height: 8),
            _buildPaymentInfo(),
            const SizedBox(height: 10),
            _buildDescription(),
            const SizedBox(height: 8),
            _buildPaymentButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo(
      String vehicleNumber,
      String customerName,
      ) {
    return Row(
      children: [
        Expanded(
          child: CustomDecoration.uTextField(
            'Vehicle Number',
            vehicleNumber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomDecoration.uTextField(
            'Customer Name',
            customerName,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceInfo(
      String serviceName,
      double rate,
      ) {
    return Row(
      children: [
        Expanded(
          child: CustomDecoration.uTextField(
            'Service Type',
            serviceName,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomDecoration.uTextField(
            'Rate / Hour',
            'रु ${rate.toStringAsFixed(2)}',
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfo() {
    return Row(
      children: [
        Expanded(
          child: CustomDecoration.uTextField(
            'Start Time',
            _formatTime(widget.entry.startTime),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomDecoration.uTextField(
            'End Time',
            _formatTime(widget.entry.endTime),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomDecoration.uTextField(
            'Duration',
            widget.controller.secondsToHHMMSS(
              widget.entry.duration,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInfo() {
    return Row(
      children: [
        Expanded(
          child: CustomDecoration.uTextField(
            'Amount',
            'रु ${widget.entry.amount.toStringAsFixed(2)}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CustomDecoration.uTextField(
            'Paid',
            'रु ${widget.entry.paidAmount.toStringAsFixed(2)}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CustomDecoration.uTextField(
            'Due',
            'रु ${widget.entry.dueAmount.toStringAsFixed(2)}',
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton() {
    final hasDue = widget.entry.dueAmount > 0;

    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        onPressed: hasDue ? _openPayment : null,
        icon: const Icon(Icons.payments),
        label: Text(
          hasDue
              ? 'Collect Customer Payment'
              : 'Fully Paid',
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return TextFormField(
      controller: descriptionController,
      focusNode: _descriptionFocusNode,
      keyboardType: TextInputType.multiline,
      maxLines: 1,
      decoration: CustomDecoration.uInputDecoration(
        labelText: 'Description',
        fillColor: const Color.fromARGB(
          73,
          249,
          251,
          250,
        ),
      ),
      onFieldSubmitted: (_) => _saveDescription(),
      onTapOutside: (_) =>
          _descriptionFocusNode.unfocus(),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();

    final hour = local.hour % 12 == 0
        ? 12
        : local.hour % 12;

    final minute =
    local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}