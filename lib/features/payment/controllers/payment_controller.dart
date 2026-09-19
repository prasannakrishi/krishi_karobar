import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';
import '../../../utils/exceptions/app_exceptions.dart';
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

  final isLoadingActivities = false.obs;
  final isSaving = false.obs;

  double get totalDue {
    return _money(
      customerActivities.fold(
        0.0,
        (sum, activity) => sum + _activityDue(activity),
      ),
    );
  }

  double get enteredAmount {
    return double.tryParse(paymentAmountController.text.trim()) ?? 0;
  }

  List<ActivityModel> get dueActivities {
    final list = customerActivities.where((activity) {
      return _activityDue(activity) > 0;
    }).toList();

    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return list;
  }

  Future<void> selectCustomer(String customerId) async {
    selectedCustomerId.value = customerId;
    selectedCustomer.value = cache.customers[customerId];

    paymentAmountController.clear();
    referenceController.clear();
    descriptionController.clear();

    await _loadCustomerDues(customerId);
  }

  Future<void> _loadCustomerDues(String customerId) async {
    isLoadingActivities.value = true;

    try {
      final query = firebaseService.getQuery(
        'activities',
        orderByChild: 'customerId',
        equalTo: customerId,
      );

      final snapshot = await query.get();
      final activities = <ActivityModel>[];

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<Object?, Object?>.from(snapshot.value as Map);

        for (final entry in data.entries) {
          if (entry.value is! Map) {
            continue;
          }

          final activityData = Map<String, dynamic>.from(entry.value as Map);

          activityData['id'] ??= entry.key?.toString();

          final activity = ActivityModel.fromMap(activityData);
          final paid = _money(activity.paidAmount);
          final due = _money(activity.amount - paid);

          if (due <= 0) {
            continue;
          }

          activity.paidAmount = paid;
          activity.dueAmount = due;

          activities.add(activity);
        }
      }

      activities.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      customerActivities.assignAll(activities);
    } catch (error) {
      debugPrint('PaymentController: Failed to load dues: $error');
      customerActivities.clear();
      _showError(AppException.messageOf(error));
    } finally {
      isLoadingActivities.value = false;
    }
  }

  void selectPaymentMethod(String method) {
    selectedPaymentMethod.value = method;

    if (method == 'cash') {
      referenceController.clear();
    }
  }

  void fillFullDue() {
    paymentAmountController.text = totalDue.toStringAsFixed(2);
    update();
  }

  List<PaymentAllocationModel> _buildAllocations(double amount) {
    var remaining = _money(amount);
    final allocations = <PaymentAllocationModel>[];

    for (final activity in dueActivities) {
      if (remaining <= 0) {
        break;
      }

      final previousDue = _activityDue(activity);

      if (previousDue <= 0) {
        continue;
      }

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

    try {
      Authz.requirePermission(Permissions.activityEdit);
    } on AppException catch (e) {
      _showError(e.message);
      return null;
    }

    if (selectedCustomerId.value.isEmpty) {
      _showError('Please select a customer.');
      return null;
    }

    if (isLoadingActivities.value) {
      _showError('Please wait while customer dues are loading.');
      return null;
    }

    final amount = _money(enteredAmount);
    final customerDue = totalDue;

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
      final paymentId = const Uuid().v4();
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
        final activityIndex = customerActivities.indexWhere(
          (item) => item.id == allocation.activityId,
        );

        if (activityIndex == -1) {
          _showError('An activity in this payment no longer exists.');
          return null;
        }

        final activity = customerActivities[activityIndex];
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

      await firebaseService.updateRecords(updates);

      _refreshLocalActivities(allocations, now);

      Get.snackbar(
        'Payment Saved',
        'Payment ${payment.uId} saved successfully.',
        snackPosition: SnackPosition.BOTTOM,
      );

      return payment;
    } catch (error) {
      debugPrint('PaymentController: $error');
      _showError(AppException.messageOf(error));
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  void _refreshLocalActivities(
    List<PaymentAllocationModel> allocations,
    DateTime now,
  ) {
    for (final allocation in allocations) {
      final index = customerActivities.indexWhere(
        (item) => item.id == allocation.activityId,
      );

      if (index == -1) {
        continue;
      }

      final activity = customerActivities[index];

      activity.paidAmount = _money(activity.paidAmount + allocation.paidAmount);

      activity.dueAmount = _money(activity.amount - activity.paidAmount);

      activity.status = _paymentStatus(activity.paidAmount, activity.amount);

      activity.paidAt = now;
      activity.receivedBy = LoginController.loginUser.id;
      activity.updatedAt = now;

      if (cache.activities.containsKey(activity.id)) {
        final cachedActivity = cache.activities[activity.id]!;

        cachedActivity.paidAmount = activity.paidAmount;
        cachedActivity.dueAmount = activity.dueAmount;
        cachedActivity.status = activity.status;
        cachedActivity.paidAt = activity.paidAt;
        cachedActivity.receivedBy = activity.receivedBy;
        cachedActivity.updatedAt = activity.updatedAt;
      }
    }

    customerActivities.refresh();
    cache.activities.refresh();

    customerActivities.removeWhere((activity) => _activityDue(activity) <= 0);
  }

  double _activityDue(ActivityModel activity) {
    return _money(activity.amount - activity.paidAmount);
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
