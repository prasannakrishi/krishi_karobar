import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/payment_controller.dart';
import 'payment_slip.dart';

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({super.key, required this.customerId});

  final String customerId;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late final PaymentController controller;

  @override
  void initState() {
    super.initState();

    controller = Get.isRegistered<PaymentController>()
        ? Get.find<PaymentController>()
        : Get.put(PaymentController());

    controller.selectCustomer(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Obx(
        () => Text(
          'Collect Payment - '
          '${controller.selectedCustomer.value?.name ?? '-'}',
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Obx(() {
          if (controller.dueActivities.isEmpty) {
            return const Text('This customer has no outstanding due.');
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dueList(),
                const SizedBox(height: 12),
                _amountField(),
                const SizedBox(height: 12),
                _methodField(),
                const SizedBox(height: 12),
                _referenceField(),
                const SizedBox(height: 12),
                _descriptionField(),
              ],
            ),
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: controller.isSaving.value
              ? null
              : () {
                  controller.reset();
                  Get.back();
                },
          child: const Text('Cancel'),
        ),
        Obx(
          () => ElevatedButton(
            onPressed:
                controller.isSaving.value || controller.dueActivities.isEmpty
                ? null
                : _savePayment,
            child: controller.isSaving.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Payment'),
          ),
        ),
      ],
    );
  }

  Widget _dueList() {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(
              flex: 2,
              child: Text(
                'Activity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                'Due',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const Divider(),
        ...controller.dueActivities.map(
          (activity) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(activity.uId)),
                Expanded(
                  child: Text(
                    'रु ${activity.dueAmount.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total Due',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              'रु ${controller.totalDue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _amountField() {
    return TextField(
      controller: controller.paymentAmountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Payment Amount',
        prefixText: 'रु ',
        suffixIcon: IconButton(
          icon: const Icon(Icons.done_all),
          onPressed: controller.totalDue <= 0 ? null : controller.fillFullDue,
        ),
      ),
    );
  }

  Widget _methodField() {
    return Obx(
      () => DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Payment Method'),
        items: const [
          DropdownMenuItem(value: 'cash', child: Text('Cash')),
          DropdownMenuItem(value: 'bankTransfer', child: Text('Bank Transfer')),
          DropdownMenuItem(value: 'eSewa', child: Text('eSewa')),
        ],
        onChanged: controller.isSaving.value
            ? null
            : (value) {
                if (value != null) {
                  controller.selectPaymentMethod(value);
                }
              },
      ),
    );
  }

  Widget _referenceField() {
    return Obx(
      () => TextField(
        controller: controller.referenceController,
        enabled: controller.selectedPaymentMethod.value != 'cash',
        decoration: InputDecoration(
          labelText: controller.selectedPaymentMethod.value == 'cash'
              ? 'Reference No. (Optional)'
              : 'Reference / Transaction No.',
        ),
      ),
    );
  }

  Widget _descriptionField() {
    return TextField(
      controller: controller.descriptionController,
      maxLines: 2,
      decoration: const InputDecoration(labelText: 'Description'),
    );
  }

  Future<void> _savePayment() async {
    final payment = await controller.savePayment();

    if (!mounted || payment == null) {
      return;
    }

    Get.back();

    await Get.dialog(PaymentSlip(payment: payment));
  }

  @override
  void dispose() {
    if (Get.isRegistered<PaymentController>()) {
      controller.reset();
    }

    super.dispose();
  }
}
