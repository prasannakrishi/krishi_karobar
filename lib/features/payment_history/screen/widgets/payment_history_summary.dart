import 'package:flutter/material.dart';

import '../../controllers/payment_history_controller.dart';

class PaymentHistorySummary extends StatelessWidget {
  const PaymentHistorySummary({
    super.key,
    required this.controller,
  });

  final PaymentHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _item(
                    'Payments',
                    controller.paymentCount.toString(),
                  ),
                ),
                Expanded(
                  child: _item(
                    'Total Collected',
                    controller.formatMoney(
                      controller.totalCollected,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _item(
                    'Cash',
                    controller.formatMoney(
                      controller.cashTotal,
                    ),
                  ),
                ),
                Expanded(
                  child: _item(
                    'Bank',
                    controller.formatMoney(
                      controller.bankTransferTotal,
                    ),
                  ),
                ),
                Expanded(
                  child: _item(
                    'eSewa',
                    controller.formatMoney(
                      controller.eSewaTotal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
      String label,
      String value,
      ) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}