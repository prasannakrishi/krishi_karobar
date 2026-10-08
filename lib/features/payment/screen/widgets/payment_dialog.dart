import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
import '../../../../utils/helper/helpers.dart';
import 'package:krishi_karobar/features/controllers.dart';
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10),
      title: Obx(
        () => Text('${controller.selectedCustomer.value?.name ?? '-'}'),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Obx(() {
          if (controller.isLoadingActivities.value) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (controller.dueActivities.isEmpty) {
            return const SizedBox(
              height: 120,
              child: Center(
                child: Text('This customer has no outstanding due.'),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dueListTable(),
                const SizedBox(height: 10),
                _amountField(),
                const SizedBox(height: 10),
                _discountField(),
                const SizedBox(height: 10),
                _methodField(),
                const SizedBox(height: 10),
                _descriptionField(),
              ],
            ),
          );
        }),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
            ),
            onPressed:
                controller.isSaving.value ||
                    controller.isLoadingActivities.value ||
                    controller.dueActivities.isEmpty
                ? null
                : _savePayment,
            child: controller.isSaving.value
                ? const SizedBox(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Payment'),
          ),
        ),
      ],
    );
  }

  Widget _dueListTable() {
    final entries = controller.dueActivities;
    return Stack(
      children: [
        uDataTable(
          columns: [
            _buildCell(
              const Text(
                'Activity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              120,
            ),
            _buildCell(
              const Text(
                'Duration',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              80,
            ),
            _buildCell(
              const Text('Rate', style: TextStyle(fontWeight: FontWeight.bold)),
              70,
            ),
            _buildCell(
              const Text('Due', style: TextStyle(fontWeight: FontWeight.bold)),
              100,
            ),
          ],
          rowValues: [
            ...entries.map(
              (activity) => [
                _buildCell(Text(activity.uId), 120),
                _buildCell(Text(secondsToHHMMSS(activity.duration)), 80),
                _buildCell(Text('रु ${activity.rate.toInt()}'), 70),
                _buildCell(
                  Text(
                    'रु ${_activityDue(activity)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  100,
                ),
              ],
            ),
            [
              _buildCell(
                const Text(
                  'Total Due',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                110,
              ),
              _buildCell(
                Text(secondsToHHMMSS(controller.totalDuration.toInt()),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                70,
              ),
              _buildCell(const Text(''), 80),
              _buildCell(
                Text(
                  'रु ${controller.totalDue.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                100,
              ),
            ],
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

  Widget _discountField() {
    return TextField(
      controller: controller.discountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Discount',
        prefixText: 'रु ',
      ),
      onChanged: controller.onDiscountChanged,
    );
  }

  Widget _methodField() {
    return Obx(
      () => DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Payment Method'),
        initialValue: controller.selectedPaymentMethod.value,
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

  Widget _descriptionField() {
    return TextField(
      controller: controller.descriptionController,
      maxLines: 1,
      decoration: const InputDecoration(labelText: 'Description'),
    );
  }

  Future<void> _savePayment() async {
    final payment = await controller.savePayment();

    if (!mounted || payment == null) {
      return;
    }

    await Get.dialog(PaymentSlip(payment: payment));

    Get.back();
  }

  int _activityDue(ActivityModel activity) {
    return (activity.amount - activity.paidAmount).round();
  }

  Widget _buildCell(Widget child, double width) {
    return SizedBox(width: width, child: child);
  }

  @override
  void dispose() {
    if (Get.isRegistered<PaymentController>()) {
      controller.reset();
    }
    super.dispose();
  }
}
