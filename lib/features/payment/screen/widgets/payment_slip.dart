import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
import '../../../../services/data_cache_service.dart';
import '../../../../utils/helper/helpers.dart';

class PaymentSlip extends StatelessWidget {
  const PaymentSlip({super.key, required this.payment});

  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    final cache = DataCacheService.instance;
    final customer = cache.customers[payment.customerId];
    final receiver = cache.users[payment.receivedBy];

    return AlertDialog(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      insetPadding: const EdgeInsets.symmetric(horizontal: 2),

      content: SizedBox(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const Divider(),

              _row('Receipt No.', payment.uId),
              _row('Date', _formatDate(payment.paidAt)),
              _row('Customer Name', customer?.name ?? '-'),
              _row('Customer Id', customer?.uId ?? '-'),
              const SizedBox(height: 8),
              _allocationTable(cache),
              const Divider(),

              _row('Total Paid', _money(payment.amount), bold: true),
              _row('Payment Method', _paymentMethodName(payment.paymentMethod)),

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
          'Prasanna Aadhunic Kridhi Kendra',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text('Dang    9858028096', textAlign: TextAlign.center),
        Text('Payment Receipt', textAlign: TextAlign.center),
      ],
    );
  }

  Widget _allocationTable(DataCacheService cache) {
    final rows = payment.allocations.map((allocation) {
      final activity = cache.activities[allocation.activityId];
      final service = activity == null ? null : cache.services[activity.serviceId];

      return [
        _buildCell(Text(activity?.uId ?? '-'), 110),
        _buildCell(Text(service?.name ?? '-'), 80),
        _buildCell(Text(_money(allocation.previousDue)), 55),
        _buildCell(Text(_money(allocation.paidAmount)), 55),
        _buildCell(Text(_money(allocation.remainingDue),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
          55,
        ),
      ];
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Text(
            'Payment Details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        uDataTable(
          columns: [
            _buildCell(
              const Text(
                'Activity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              110,
            ),
            _buildCell(
              const Text(
                'Service',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              80,
            ),
            _buildCell(
              const Text(
                'Due रु ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              55,
            ),
            _buildCell(
              const Text(
                'Paid रु ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              55,
            ),
            _buildCell(
              const Text(
                'Remain रु ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              70,
            ),
          ],
          rowValues: rows,
        ),
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
            width: 135,
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
    return '${value.toInt()}';
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

  Widget _buildCell(Widget child, double width) {
    return SizedBox(width: width, child: child);
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
