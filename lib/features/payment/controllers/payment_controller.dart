import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/models.dart';
import '../../../services/services.dart';
import '../../authentication/controllers/login_controllers.dart';

class PaymentController extends GetxController {
  static PaymentController get instance => Get.find();

  final firebaseService = FirebaseService();
  final cache = DataCacheService.instance;
  final sequenceService = Get.find<SequenceService>();

  final selectedCustomerId = ''.obs;
  final selectedPaymentMethod = 'cash'.obs;

  final paymentAmountController = TextEditingController();
  final referenceController = TextEditingController();
  final descriptionController = TextEditingController();

  final customerActivities = <ActivityModel>[].obs;
  final selectedCustomer = Rxn<CustomerModel>();

  final isSaving = false.obs;

  double get totalDue {
    return customerActivities.fold(
      0.0,
      (sum, activity) => sum + activity.dueAmount,
    );
  }

  double get enteredAmount {
    return double.tryParse(paymentAmountController.text.trim()) ?? 0;
  }

  List<ActivityModel> get dueActivities {
    final list = customerActivities
        .where((activity) => activity.dueAmount > 0)
        .toList();

    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return list;
  }

  void selectCustomer(String customerId) {
    selectedCustomerId.value = customerId;
    selectedCustomer.value = cache.customers[customerId];

    _loadCustomerDues(customerId);

    paymentAmountController.clear();
    referenceController.clear();
    descriptionController.clear();
  }

  void _loadCustomerDues(String customerId) {
    final activities = cache.activities.values
        .where(
          (activity) =>
              activity.customerId == customerId && activity.dueAmount > 0,
        )
        .toList();

    activities.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    customerActivities.assignAll(activities);
  }

  void selectPaymentMethod(String method) {
    selectedPaymentMethod.value = method;

    if (method == 'cash') {
      referenceController.clear();
    }
  }

  void fillFullDue() {
    paymentAmountController.text = _money(totalDue).toStringAsFixed(2);

    update();
  }

  List<PaymentAllocationModel> _buildAllocations(double amount) {
    var remaining = _money(amount);

    final allocations = <PaymentAllocationModel>[];

    for (final activity in dueActivities) {
      if (remaining <= 0) {
        break;
      }

      final previousDue = _money(activity.dueAmount);

      final paidNow = _money(
        remaining >= previousDue ? previousDue : remaining,
      );

      final remainingDue = _money(previousDue - paidNow);

      if (paidNow <= 0) {
        continue;
      }

      allocations.add(
        PaymentAllocationModel(
          activityId: activity.id,
          previousDue: previousDue,
          paidAmount: paidNow,
          remainingDue: remainingDue,
        ),
      );

      remaining = _money(remaining - paidNow);
    }

    return allocations;
  }

  Future<PaymentModel?> savePayment() async {
    if (isSaving.value) {
      return null;
    }

    if (selectedCustomerId.value.isEmpty) {
      _showError('Please select a customer.');
      return null;
    }

    final amount = _money(enteredAmount);
    final customerDue = _money(totalDue);

    if (amount <= 0) {
      _showError('Payment amount must be greater than zero.');
      return null;
    }

    if (customerDue <= 0) {
      _showError('This customer has no outstanding due.');
      return null;
    }

    if (amount > customerDue) {
      _showError('Payment cannot be greater than customer due.');
      return null;
    }

    final paymentMethod = selectedPaymentMethod.value.trim();

    if (paymentMethod.isEmpty) {
      _showError('Please select a payment method.');
      return null;
    }

    final referenceNo = referenceController.text.trim();

    if (paymentMethod != 'cash' && referenceNo.isEmpty) {
      _showError('Reference / transaction number is required.');
      return null;
    }

    final allocations = _buildAllocations(amount);

    if (allocations.isEmpty) {
      _showError('No outstanding activity due found.');
      return null;
    }

    final allocatedAmount = _money(
      allocations.fold(0.0, (sum, item) => sum + item.paidAmount),
    );

    if (allocatedAmount != amount) {
      _showError('Payment could not be fully allocated.');
      return null;
    }

    isSaving.value = true;

    try {
      final now = DateTime.now();
      final paymentId = await _createPaymentId();
      final paymentUid = await sequenceService.generateSequence('P');

      final payment = PaymentModel(
        id: paymentId,
        uId: paymentUid,
        customerId: selectedCustomerId.value,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNo: referenceNo.isEmpty ? null : referenceNo,
        receivedBy: LoginController.loginUser.id,
        paidAt: now,
        allocations: allocations,
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        createdAt: now,
      );

      final updates = <String, dynamic>{'payments/$paymentId': payment.toMap()};

      for (final allocation in allocations) {
        final activity = cache.activities[allocation.activityId];

        if (activity == null) {
          _showError('An activity in this payment no longer exists.');
          return null;
        }

        final oldPaid = _money(activity.paidAmount);

        final activityAmount = _money(activity.amount);

        final newPaid = _money(oldPaid + allocation.paidAmount);

        if (newPaid > activityAmount) {
          _showError('Payment exceeds activity amount.');
          return null;
        }

        final newDue = _money(activityAmount - newPaid);

        final status = _paymentStatus(newPaid, activityAmount);

        final activityPath = 'activities/${activity.id}';

        updates['$activityPath/paidAmount'] = newPaid;

        updates['$activityPath/dueAmount'] = newDue;

        updates['$activityPath/status'] = status;

        updates['$activityPath/paidAt'] = now.toUtc().toIso8601String();

        updates['$activityPath/receivedBy'] = LoginController.loginUser.id;

        updates['$activityPath/updatedAt'] = now.toUtc().toIso8601String();
      }

      final success = await firebaseService.updateRecords(updates);

      if (!success) {
        _showError('Payment could not be saved.');
        return null;
      }

      _refreshLocalActivities(allocations, now);

      Get.snackbar(
        'Payment Saved',
        'Payment ${payment.uId} saved successfully.',
        snackPosition: SnackPosition.BOTTOM,
      );

      return payment;
    } catch (error) {
      debugPrint('PaymentController: $error');

      _showError('Payment failed. Please try again.');

      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<String> _createPaymentId() async {
    final ref = firebaseService.getQuery('payments');

    return ref.ref.push().key ??
        DateTime.now().microsecondsSinceEpoch.toString();
  }

  void _refreshLocalActivities(
    List<PaymentAllocationModel> allocations,
    DateTime now,
  ) {
    for (final allocation in allocations) {
      final activity = cache.activities[allocation.activityId];

      if (activity == null) {
        continue;
      }

      activity.paidAmount = _money(activity.paidAmount + allocation.paidAmount);

      activity.dueAmount = _money(activity.amount - activity.paidAmount);

      activity.status = _paymentStatus(activity.paidAmount, activity.amount);

      activity.paidAt = now;
      activity.receivedBy = LoginController.loginUser.id;
      activity.updatedAt = now;
    }

    cache.activities.refresh();

    _loadCustomerDues(selectedCustomerId.value);
  }

  String _paymentStatus(double paid, double amount) {
    if (paid <= 0) {
      return 'due';
    }

    if (paid >= amount) {
      return 'paid';
    }

    return 'partial';
  }

  double _money(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  void _showError(String message) {
    Get.snackbar('Payment Error', message, snackPosition: SnackPosition.BOTTOM);
  }

  void reset() {
    selectedCustomerId.value = '';
    selectedCustomer.value = null;
    selectedPaymentMethod.value = 'cash';

    customerActivities.clear();

    paymentAmountController.clear();
    referenceController.clear();
    descriptionController.clear();
  }

  @override
  void onClose() {
    paymentAmountController.dispose();
    referenceController.dispose();
    descriptionController.dispose();

    super.onClose();
  }
}
