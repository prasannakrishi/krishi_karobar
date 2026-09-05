import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:get/get.dart';

import '../../../payment/screen/widgets/payment_slip.dart';
import '../../controllers/payment_history_controller.dart';

class PaymentHistoryCard extends StatelessWidget {
  const PaymentHistoryCard({
    super.key,
    required this.controller,
    required this.index,
  });

  final PaymentHistoryController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final payment = controller.filteredPayments[index];

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Iconsax.receipt_item),
        ),
        title: Text(
          controller.customerName(payment.customerId),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payment.uId),
            Text(
              '${controller.paymentMethodName(payment.paymentMethod)}'
                  ' • ${controller.formatDate(payment.paidAt)}',
            ),
            if (payment.referenceNo != null)
              Text(
                'Ref: ${payment.referenceNo}',
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              controller.formatMoney(payment.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'View Receipt',
              onPressed: () {
                Get.dialog(
                  PaymentSlip(
                    payment: payment,
                  ),
                );
              },
              icon: const Icon(Iconsax.receipt),
            ),
          ],
        ),
        onTap: () {
          controller.selectIndex(index);
        },
      ),
    );
  }
}