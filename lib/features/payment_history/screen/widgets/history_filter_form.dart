import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/payment_history_controller.dart';

class HistoryFilterForm extends StatelessWidget {
  const HistoryFilterForm({
    super.key,
    required this.controller,
  });

  final PaymentHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(
              () => DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Customer',
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All Customers'),
              ),
              ...controller.customers.map(
                    (customer) => DropdownMenuItem<String>(
                  value: customer.id,
                  child: Text(customer.name),
                ),
              ),
            ],
            onChanged: (value) {
              controller.selectCustomer(value ?? '');
            },
          ),
        ),
        const SizedBox(height: 12),
        Obx(
              () => DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Payment Method',
            ),
            items: const [
              DropdownMenuItem(
                value: 'All',
                child: Text('All Methods'),
              ),
              DropdownMenuItem(
                value: 'cash',
                child: Text('Cash'),
              ),
              DropdownMenuItem(
                value: 'bankTransfer',
                child: Text('Bank Transfer'),
              ),
              DropdownMenuItem(
                value: 'eSewa',
                child: Text('eSewa'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                controller.selectPaymentMethod(value);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        Obx(
              () => InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2050),
                initialDateRange:
                controller.fromDate.value != null &&
                    controller.toDate.value != null
                    ? DateTimeRange(
                  start: controller.fromDate.value!,
                  end: controller.toDate.value!,
                )
                    : null,
              );

              if (range != null) {
                controller.setDateRange(range);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date Range',
              ),
              child: Text(
                _dateRangeText(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: controller.clearFilters,
              child: const Text('Clear'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: Get.back,
              child: const Text('Apply'),
            ),
          ],
        ),
      ],
    );
  }

  String _dateRangeText() {
    final from = controller.fromDate.value;
    final to = controller.toDate.value;

    if (from == null || to == null) {
      return 'All Dates';
    }

    return '${_formatDate(from)} - ${_formatDate(to)}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}