import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
import '../../../../services/data_cache_service.dart';

class PaymentSlip extends StatelessWidget {
  const PaymentSlip({super.key, required this.payment});

  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    final cache = DataCacheService.instance;

    final customer = cache.customers[payment.customerId];

    final receiver = cache.users[payment.receivedBy];

    return AlertDialog(
      title: const Center(
        child: Text(
          'PAYMENT RECEIPT',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              const Divider(),

              _row('Receipt No.', payment.uId),
              _row('Date', _formatDate(payment.paidAt)),
              _row('Customer', customer?.name ?? '-'),
              _row('Phone', customer?.phone ?? '-'),

              const SizedBox(height: 14),

              _buildAllocationSection(cache),

              const SizedBox(height: 8),
              const Divider(),

              _row('Total Paid', _money(payment.amount), bold: true),
              _row('Payment Method', _paymentMethodName(payment.paymentMethod)),

              if (_hasText(payment.referenceNo))
                _row('Reference No.', payment.referenceNo!),

              _row('Received By', receiver?.fullname ?? '-'),

              if (_hasText(payment.description)) ...[
                const SizedBox(height: 8),
                _row('Note', payment.description!),
              ],

              const SizedBox(height: 18),

              const Center(
                child: Text(
                  'Thank you!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: Get.back, child: const Text('Close'))],
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'Krishi Karobar',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text('Payment Receipt', textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildAllocationSection(DataCacheService cache) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Payment Allocation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Divider(),

        ...payment.allocations.map((allocation) {
          final activity = cache.activities[allocation.activityId];

          final service = activity == null
              ? null
              : cache.services[activity.serviceId];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  service?.name ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (activity != null)
                  Text(
                    activity.uId,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                const SizedBox(height: 4),
                _row('Previous Due', _money(allocation.previousDue)),
                _row('Paid', _money(allocation.paidAmount)),
                _row('Remaining', _money(allocation.remainingDue)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final weight = bold ? FontWeight.bold : FontWeight.normal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(label, style: TextStyle(fontWeight: weight)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: weight)),
          ),
        ],
      ),
    );
  }

  String _money(double value) {
    return 'रु ${value.toStringAsFixed(2)}';
  }

  String _paymentMethodName(String method) {
    switch (method) {
      case 'bankTransfer':
        return 'Bank Transfer';
      case 'eSewa':
        return 'eSewa';
      default:
        return 'Cash';
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();

    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
