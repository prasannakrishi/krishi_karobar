import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:krishi_karobar/offline/core/workspace_scope.dart';
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
  final discountController = TextEditingController();
  final referenceController = TextEditingController();
  final descriptionController = TextEditingController();

  final customerActivities = <ActivityModel>[].obs;
  final selectedCustomer = Rxn<CustomerModel>();

  final isLoadingActivities = false.obs;
  final isSaving = false.obs;

  int get totalDue {
    return customerActivities.fold(0,(sum, activity) => sum + _activityDue(activity));
  }
  int get totalDuration {
      return customerActivities.fold(0,(sum, activity) => sum + activity.duration);
    }

  int get enteredAmount {
    return int.tryParse(paymentAmountController.text.trim()) ?? 0;
  }

  int get enteredDiscount {
    return int.tryParse(discountController.text.trim()) ?? 0;
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
    discountController.clear();
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
          final paid = activity.paidAmount;
          final due = activity.amount - paid;

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

  void onDiscountChanged(String value) {
    final discount = int.tryParse(value.trim()) ?? 0;
    final netAmount = (totalDue - discount).clamp(0, totalDue);
    paymentAmountController.text = netAmount.toString();
  }

  void fillFullDue() {
    discountController.text = '0';
    paymentAmountController.text = totalDue.toStringAsFixed(0);
    update();
  }

  List<PaymentAllocationModel> _buildAllocations(int cashAmount, int discountAmount) {
    var remainingCash = cashAmount;
    var remainingDiscount = discountAmount;
    final allocations = <PaymentAllocationModel>[];

    for (final activity in dueActivities) {
      if (remainingCash <= 0 && remainingDiscount <= 0) {
        break;
      }

      final previousDue = _activityDue(activity);

      if (previousDue <= 0) {
        continue;
      }

      final discountForThis = remainingDiscount >= previousDue
          ? previousDue
          : remainingDiscount;

      final dueAfterDiscount = previousDue - discountForThis;

      final cashForThis = remainingCash >= dueAfterDiscount
          ? dueAfterDiscount
          : remainingCash;

      final totalPaidForThis = cashForThis + discountForThis;
      final remainingDue = previousDue - totalPaidForThis;

      if (totalPaidForThis <= 0) {
        continue;
      }

      allocations.add(
        PaymentAllocationModel(
          activityId: activity.id,
          previousDue: previousDue,
          paidAmount: cashForThis,
          discount: discountForThis,
          remainingDue: remainingDue,
        ),
      );

      remainingCash -= cashForThis;
      remainingDiscount -= discountForThis;
    }

    return allocations;
  }

  Future<PaymentModel?> savePayment() async {
    if (isSaving.value) {
      return null;
    }

    try {
      Authz.requirePermission(Permissions.paymentCreate);
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

    final amount = enteredAmount;
    final discount = enteredDiscount;
    final customerDue = totalDue;

    if (amount < 0 || discount < 0) {
      _showError('Amount and discount cannot be negative.');
      return null;
    }

    if ((amount + discount) <= 0) {
      _showError('Payment amount or discount must be greater than zero.');
      return null;
    }

    if (customerDue <= 0) {
      _showError('This customer has no outstanding due.');
      return null;
    }

    if ((amount + discount) > customerDue) {
      _showError('Total payment and discount cannot be greater than customer due.');
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

    final allocations = _buildAllocations(amount, discount);

    if (allocations.isEmpty) {
      _showError('No outstanding activity due found.');
      return null;
    }

    final allocatedTotal = allocations.fold(
      0,
      (sum, item) => sum + item.paidAmount + item.discount,
    );

    if (allocatedTotal != (amount + discount)) {
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
        discount: discount,
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
        final oldPaid = activity.paidAmount;
        final activityAmount = activity.amount;
        final paidAmount = allocation.paidAmount;
        final discountAmount = allocation.discount;
        final newPaid = oldPaid + paidAmount + discountAmount;

        if (newPaid > activityAmount) {
          _showError('Payment exceeds activity amount.');
          return null;
        }

        final newDue = activityAmount - newPaid;
        final status = _paymentStatus(newPaid, activityAmount);
        final activityPath = 'activities/${activity.id}';

        updates['$activityPath/paidAmount'] = newPaid;
        updates['$activityPath/discountAmount'] = discountAmount;
        updates['$activityPath/dueAmount'] = newDue;
        updates['$activityPath/status'] = status;
        updates['$activityPath/paidAt'] = now.toUtc().toIso8601String();
        updates['$activityPath/receivedBy'] = LoginController.loginUser.id;
        updates['$activityPath/updatedAt'] = now.toUtc().toIso8601String();
      }

      try {
        if (OfflineStorage.isAvailable) {
          final workspaceId = LoginController.loginUser.id;
          final authUid = FirebaseAuth.instance.currentUser?.uid ?? workspaceId;
          final scope = WorkspaceScope.forCurrentEnvironment(
            ownerUserId: workspaceId,
            authUid: authUid,
            vehicleId: 'default',
          );
          await OfflineStorage.instance.localRecords.saveRecord(
            scope,
            entityType: 'payments',
            recordId: paymentId,
            data: payment.toMap(),
            isNew: true,
          );
        }
      } catch (e) {
        debugPrint('PaymentController offline payment save notice: $e');
      }

      await firebaseService.updateRecords(updates);

      cache.payments[paymentId] = payment;
      cache.payments.refresh();

      _refreshLocalActivities(allocations, now);
      cache.activities.refresh();

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

      final settlement = allocation.paidAmount + allocation.discount;
      activity.paidAmount = activity.paidAmount + settlement;

      activity.dueAmount = activity.amount - activity.paidAmount;

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

  int _activityDue(ActivityModel activity) {
    return activity.amount - activity.paidAmount;
  }

  String _paymentStatus(int paid, int amount) {
    if (paid <= 0) {
      return 'due';
    }

    if (paid >= amount) {
      return 'paid';
    }

    return 'partial';
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
    discountController.clear();
    referenceController.clear();
    descriptionController.clear();
  }

  @override
  void onClose() {
    paymentAmountController.dispose();
    discountController.dispose();
    referenceController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}
