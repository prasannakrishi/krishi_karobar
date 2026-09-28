import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
import '../../../../services/services.dart';
import '../../../../utils/helper/nepali_date_time.dart';
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

    final vehicle =cache.vehicles[widget.entry.vehicleId];

    final customer =cache.customers[widget.entry.customerId];

    final service =cache.services[widget.entry.serviceId];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color.fromARGB(255,228,247,248),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            _buildBasicInfo(vehicle?.number ?? '-',customer?.name ?? '-',customer?.uId ?? ''),
            const SizedBox(height: 8),
            _buildServiceInfo(customer?.address ?? '',service?.name ?? '-', widget.entry.rate),
            const SizedBox(height: 8),
            _buildTimeInfo(),
            const SizedBox(height: 8),
            _buildPaymentInfo(),
            const SizedBox(height: 8),
            _buildDescription(),
            if (Authz.canViewActivityGps())...[
              const SizedBox(height: 8),
              _buildGpsInfo(),
            ],
            const SizedBox(height: 8),
            _buildPaymentButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo(String vehicleNumber,String customerName, String customerUId) {
    return Row(
      children: [
        Flexible(
          flex: 1,
          child: CustomDecoration.uTextField('Vehicle Number',vehicleNumber),
        ),
        const SizedBox(width: 5),
        Flexible(
          flex: 2,
          child: CustomDecoration.uTextField('Customer Name', "$customerName  ($customerUId)"),
        ),
      ],
    );
  }

  Widget _buildServiceInfo(String customerAddress,String serviceName,int rate) {
    return Row(
      children: [
        Expanded(
          child: CustomDecoration.uTextField('Customer Address',customerAddress),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: CustomDecoration.uTextField('Service Type',serviceName),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: CustomDecoration.uTextField('Rate / Hour','रु ${rate.toStringAsFixed(0)}',
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
            _formatTime(widget.entry.startTime)
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: CustomDecoration.uTextField(
            'End Time',
            _formatTime(widget.entry.endTime)
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: CustomDecoration.uTextField('Duration',
            widget.controller.secondsToHHMMSS(widget.entry.duration)
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
            'रु ${widget.entry.amount.toStringAsFixed(2)}'
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: CustomDecoration.uTextField(
            'Paid',
            'रु ${widget.entry.paidAmount.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: CustomDecoration.uTextField(
            'Due',
            'रु ${widget.entry.dueAmount.toStringAsFixed(0)}'
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton() {
    final hasDue = widget.entry.dueAmount > 0;

    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: hasDue ? _openPayment : null,
        icon: const Icon(Icons.payments),
        label: Text(
          hasDue ? 'Collect Customer Payment' : 'View Bill',
        ),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero, // 👈 vertical padding हटाइयो
          minimumSize: const Size(0, 50), // height control
          alignment: Alignment.center, // content center मा राख्न
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
        fillColor: const Color.fromARGB(73,249,251,250),
      ),
      onFieldSubmitted: (_) => _saveDescription(),
      onTapOutside: (_) =>
          _descriptionFocusNode.unfocus(),
    );
  }

  Widget _buildGpsInfo() {
    final startLoc = widget.entry.startLocation;
    final stopLoc = widget.entry.stopLocation;

    if (startLoc == null && stopLoc == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'GPS Location: Not available for this activity',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.blue),
              SizedBox(width: 4),
              Text(
                'Activity GPS Locations (Admin Only)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (startLoc != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Start: ${startLoc.latitude.toStringAsFixed(6)}, ${startLoc.longitude.toStringAsFixed(6)} (±${startLoc.accuracy.toStringAsFixed(0)}m)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => LocationService.instance.openMap(
                      startLoc.latitude,
                      startLoc.longitude,
                    ),
                    icon: const Icon(Icons.map, size: 14),
                    label: const Text('Open Map', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          if (stopLoc != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stop: ${stopLoc.latitude.toStringAsFixed(6)}, ${stopLoc.longitude.toStringAsFixed(6)} (±${stopLoc.accuracy.toStringAsFixed(0)}m)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => LocationService.instance.openMap(
                    stopLoc.latitude,
                    stopLoc.longitude,
                  ),
                  icon: const Icon(Icons.map, size: 14),
                  label: const Text('Open Map', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    return formatNepaliTime(value);
  }
}