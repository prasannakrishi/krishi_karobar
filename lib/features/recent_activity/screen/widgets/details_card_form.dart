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

class _DetailsCardFormState extends State<DetailsCardForm> {
  late TextEditingController descriptionController;
  final FocusNode _descriptionFocusNode = FocusNode();
  String? _placeName;

  @override
  void initState() {
    super.initState();

    descriptionController = TextEditingController(
      text: widget.entry.description ?? '',
    );

    _fetchPlaceName();

    _descriptionFocusNode.addListener(() {
      if (!_descriptionFocusNode.hasFocus) {
        _saveDescription();
      }
    });
  }

  @override
  void didUpdateWidget(DetailsCardForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.startLocation != widget.entry.startLocation) {
      descriptionController.text = widget.entry.description ?? '';
      _fetchPlaceName();
    }
  }

  void _fetchPlaceName() async {
    ActivityLocationModel? startLoc = widget.entry.startLocation;

    if (startLoc == null) {
      try {
        final locData = await LocationService.instance.getActivityLocations(widget.entry.id);
        if (locData != null && locData['startLocation'] != null && locData['startLocation'] is Map) {
          startLoc = ActivityLocationModel.fromMap(
            Map<String, dynamic>.from(locData['startLocation'] as Map),
          );
          widget.entry.startLocation = startLoc;
        }
      } catch (e) {
        debugPrint('DetailsCardForm.getActivityLocations error: $e');
      }
    }

    if (startLoc != null) {
      final name = await LocationService.instance.getAddressFromCoordinates(
        startLoc.latitude,
        startLoc.longitude,
      );
      if (mounted) {
        setState(() {
          _placeName = name;
        });
      }
    } else {
      if (mounted && _placeName != null) {
        setState(() {
          _placeName = null;
        });
      }
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
            const SizedBox(height: 8),
            _buildGpsInfo(),
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
    final isAdmin = Authz.canViewActivityGps();

    final locationText = _placeName ??
        (startLoc != null
            ? '${startLoc.latitude.toStringAsFixed(4)}, ${startLoc.longitude.toStringAsFixed(4)} (Fetching place name...)'
            : 'Location not captured');

    if (startLoc == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color.fromARGB(73, 249, 251, 250),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_off_outlined, size: 18, color: Colors.grey),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Location not captured',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Admin View: 1-line interactive row displaying Icon + Place Name, opens Google Maps on tap
    if (isAdmin) {
      return InkWell(
        onTap: () => LocationService.instance.openMap(
          startLoc.latitude,
          startLoc.longitude,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locationText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.open_in_new, size: 14, color: Colors.blue),
            ],
          ),
        ),
      );
    }

    // All other users: 1-line plain text view (Icon + Place Name, non-clickable)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(73, 249, 251, 250),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              locationText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    /*
    // Stop Location UI commented out per requirement for now
    final stopLoc = widget.entry.stopLocation;
    if (stopLoc != null) {
      // Stop location display code preserved here for future use
    }
    */
  }

  String _formatTime(DateTime value) {
    return formatNepaliTime(value);
  }
}