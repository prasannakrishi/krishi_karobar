import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/models.dart';
import '../../../services/data_cache_service.dart';
import '../../../utils/helper/nepali_date_time.dart';

class PaymentHistoryController extends GetxController {
  static PaymentHistoryController get instance => Get.find();

  final cache = DataCacheService.instance;

  final payments = <PaymentModel>[].obs;
  final filteredPayments = <PaymentModel>[].obs;

  final selectedCustomerId = ''.obs;
  final selectedPaymentMethod = 'All'.obs;

  final searchQuery = ''.obs;

  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  final selectedIndex = RxnInt();

  final isLoading = false.obs;

  List<CustomerModel> get customers {
    final list = cache.customers.values.toList();

    list.sort(
          (a, b) => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
    );

    return list;
  }

  int get totalCollected {
    return filteredPayments.fold(0,(sum, payment) => sum + payment.amount);
  }

  int get paymentCount => filteredPayments.length;

  int get cashTotal => _totalByMethod('cash');

  int get bankTransferTotal =>
      _totalByMethod('bankTransfer');

  int get eSewaTotal => _totalByMethod('eSewa');

  @override
  void onInit() {
    super.onInit();

    ever(cache.payments, (_) {
      loadPayments();
    });

    loadPayments();
  }

  void loadPayments() {
    isLoading.value = true;

    final list = cache.payments.values.toList();

    list.sort(
          (a, b) => b.paidAt.compareTo(a.paidAt),
    );

    payments.assignAll(list);

    _applyFilters();

    isLoading.value = false;
  }

  void setSearchQuery(String value) {
    searchQuery.value = value.trim().toLowerCase();
    _applyFilters();
  }

  void selectCustomer(String customerId) {
    selectedCustomerId.value = customerId;
    _applyFilters();
  }

  void selectPaymentMethod(String method) {
    selectedPaymentMethod.value = method;
    _applyFilters();
  }

  void setDateRange(DateTimeRange? range) {
    if (range == null) {
      fromDate.value = null;
      toDate.value = null;
    } else {
      // The range comes from the Bikram Sambat picker (see
      // pickNepaliDateRange) - these are calendar days with no timezone
      // attached, so anchor them to real Nepal Standard Time instants
      // here rather than comparing them as device-local time.
      fromDate.value = nepalCalendarDayBoundary(range.start);
      toDate.value = nepalCalendarDayBoundary(range.end, endOfDay: true);
    }

    _applyFilters();
  }

  void clearFilters() {
    selectedCustomerId.value = '';
    selectedPaymentMethod.value = 'All';
    searchQuery.value = '';
    fromDate.value = null;
    toDate.value = null;
    selectedIndex.value = null;

    _applyFilters();
  }

  void selectIndex(int index) {
    if (index < 0 || index >= filteredPayments.length) {
      selectedIndex.value = null;
      return;
    }

    selectedIndex.value = index;
  }

  bool get hasActiveFilters {
    return selectedCustomerId.value.isNotEmpty ||
        selectedPaymentMethod.value != 'All' ||
        searchQuery.value.isNotEmpty ||
        fromDate.value != null ||
        toDate.value != null;
  }

  PaymentModel? get selectedPayment {
    final index = selectedIndex.value;

    if (index == null ||
        index < 0 ||
        index >= filteredPayments.length) {
      return null;
    }

    return filteredPayments[index];
  }

  String customerName(String customerId) {
    return cache.customers[customerId]?.name ?? '-';
  }

  String receivedByName(String userId) {
    return cache.users[userId]?.fullname ?? '-';
  }

  String paymentMethodName(String method) {
    switch (method) {
      case 'bankTransfer':
        return 'Bank Transfer';
      case 'eSewa':
        return 'eSewa';
      default:
        return 'Cash';
    }
  }

  String formatDate(DateTime value) {
    return formatNepaliDateTimeShort(value);
  }

  String formatMoney(int value) {
    return 'रु ${value}';
  }

  void _applyFilters() {
    final query = searchQuery.value;

    final result = payments.where((payment) {
      if (selectedCustomerId.value.isNotEmpty &&
          payment.customerId != selectedCustomerId.value) {
        return false;
      }

      if (selectedPaymentMethod.value != 'All' &&
          payment.paymentMethod != selectedPaymentMethod.value) {
        return false;
      }

      final paidAt = payment.paidAt;

      if (fromDate.value != null &&
          paidAt.isBefore(fromDate.value!)) {
        return false;
      }

      if (toDate.value != null &&
          paidAt.isAfter(toDate.value!)) {
        return false;
      }

      if (query.isNotEmpty) {
        final customer = customerName(payment.customerId);
        final method = paymentMethodName(payment.paymentMethod);

        final searchableText = [
          payment.uId,
          customer,
          payment.referenceNo ?? '',
          method,
        ].join(' ').toLowerCase();

        if (!searchableText.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    filteredPayments.assignAll(result);

    if (selectedIndex.value != null && selectedIndex.value! >= filteredPayments.length)
    {
      selectedIndex.value = null;
    }
  }

  int _totalByMethod(String method) {
    return filteredPayments.where((payment) => payment.paymentMethod == method)
        .fold(0,(sum, payment) => sum + payment.amount);
  }
}