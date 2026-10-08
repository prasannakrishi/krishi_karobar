import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
import '../../../../services/services.dart';
import '../../../../utils/helper/helpers.dart';
import '../../../../utils/helper/nepali_date_time.dart';
import '../../../../utils/theme/widget_themes/custom_decoration.dart';
import '../../../payment/screen/widgets/payment_dialog.dart';
import '../../../payment/screen/widgets/payment_slip.dart';
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

  void _openBill() {
    final cache = DataCacheService.instance;
    final activity = widget.entry;

    // 1. Search cache.payments for all PaymentModel containing activity.id
    final matchingPayments = cache.payments.values
        .where((payment) =>
            payment.allocations.any((alloc) => alloc.activityId == activity.id))
        .toList();

    matchingPayments.sort((a, b) => b.paidAt.compareTo(a.paidAt));

    if (matchingPayments.length == 1) {
      Get.dialog(PaymentSlip(payment: matchingPayments.first));
      return;
    }

    if (matchingPayments.length > 1) {
      Get.dialog(
        AlertDialog(
          title: const Text('Select Payment Receipt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: matchingPayments.map((payment) {
              return ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.teal),
                title: Text('Receipt #${payment.uId}'),
                subtitle: Text('Amount: रु ${payment.amount} • ${formatNepaliDateTimeShort(payment.paidAt)}'),
                onTap: () {
                  Get.back();
                  Get.dialog(PaymentSlip(payment: payment));
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Fallback: Build synthetic payment for same-time paid activities
    final syntheticPayment = _createSyntheticPayment(activity, cache);
    Get.dialog(PaymentSlip(payment: syntheticPayment));
  }

  PaymentModel _createSyntheticPayment(ActivityModel activity, DataCacheService cache) {
    final sameTimeActivities = cache.activities.values.where((a) {
      if (a.customerId != activity.customerId) return false;
      if (a.paidAmount <= 0 && a.discountAmount <= 0) return false;

      if (activity.paidAt != null && a.paidAt != null) {
        return a.paidAt!.difference(activity.paidAt!).inMinutes.abs() <= 1;
      }
      return a.id == activity.id;
    }).toList();

    final allocations = sameTimeActivities.map((a) {
      final paid = a.paidAmount;
      final disc = a.discountAmount;
      final amount = a.amount;
      final due = a.dueAmount;
      final prevDue = paid + disc + due;
      return PaymentAllocationModel(
        activityId: a.id,
        previousDue: prevDue > 0 ? prevDue : amount,
        paidAmount: paid,
        discount: disc,
        remainingDue: due,
      );
    }).toList();

    final totalPaid = allocations.fold(0, (sum, item) => sum + item.paidAmount);
    final totalDisc = allocations.fold(0, (sum, item) => sum + item.discount);

    return PaymentModel(
      id: 'syn_${activity.id}',
      uId: 'P-${activity.uId}',
      customerId: activity.customerId,
      amount: totalPaid,
      discount: totalDisc,
      paymentMethod: 'cash',
      receivedBy: activity.receivedBy ?? activity.supervisorId,
      paidAt: activity.paidAt ?? activity.createdAt,
      allocations: allocations,
      description: activity.description,
      createdAt: activity.createdAt,
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
            'रु ${widget.entry.amount.toStringAsFixed(0)}',
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
            'Discount',
            'रु ${widget.entry.discountAmount.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: CustomDecoration.uTextField(
            'Due',
            'रु ${widget.entry.dueAmount.toStringAsFixed(0)}',
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton() {
    final hasDue = widget.entry.dueAmount > 0;
    final hasPaid = widget.entry.paidAmount > 0 || widget.entry.discountAmount > 0;

    if (hasDue && hasPaid) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openBill,
                icon: const Icon(Icons.receipt_long, size: 20),
                label: const Text('View Bill'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _openPayment,
                icon: const Icon(Icons.payments, size: 20),
                label: const Text('Collect Payment'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: hasDue
            ? _openPayment
            : (hasPaid ? _openBill : null),
        icon: Icon(hasDue ? Icons.payments : Icons.receipt_long, size: 20),
        label: Text(
          hasDue ? 'Collect Customer Payment' : 'View Bill',
        ),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(double.infinity, 48),
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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