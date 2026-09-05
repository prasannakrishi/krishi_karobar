import 'package:flutter/material.dart';

import '../../controllers/payment_history_controller.dart';
import 'payment_history_card.dart';

class PaymentHistoryList extends StatelessWidget {
  const PaymentHistoryList({
    super.key,
    required this.controller,
  });

  final PaymentHistoryController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.filteredPayments.isEmpty) {
      return const Center(
        child: Text(
          'No payment records found.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 8,
      ),
      itemCount: controller.filteredPayments.length,
      itemBuilder: (context, index) {
        return PaymentHistoryCard(
          controller: controller,
          index: index,
        );
      },
    );
  }
}