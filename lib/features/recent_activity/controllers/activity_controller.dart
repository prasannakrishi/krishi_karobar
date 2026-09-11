import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import '../../../models/models.dart';
import '../../../services/data_cache_service.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/helper/helper_method.dart';

class ActivityController extends GetxController {
  static ActivityController get instance => Get.find();

  final firebaseService = FirebaseService();
  final localStorage = GetStorage();
  final cache = DataCacheService.instance;

  final filterStartDate = TextEditingController();
  final filterEndDate = TextEditingController();

  final activities = <ActivityModel>[].obs;

  final selectedIndex = RxnInt(null);
  final currentPageIndex = 0.obs;

  final selectedFilter = 'Today'.obs;
  final filterOptions = ['Today', 'Week', 'Month', 'All'];

  final nameSearchQuery = ''.obs;
  final selectedServiceFilter = 'All'.obs;

  final selectedVehicleIds = <String>[].obs;
  final selectedCustomerIds = <String>[].obs;
  final selectedStaffIds = <String>[].obs;

  final isLoading = false.obs;

  final sections = ['Paid', 'Due', 'Partial'];

  List<ActivityModel> get allActivities =>
      cache.activities.values.toList();

  List<VehicleModel> get vehicles =>
      cache.vehicles.values.toList();

  List<UserModel> get users =>
      cache.users.values.toList();

  List<CustomerModel> get customers =>
      cache.customers.values.toList();

  List<ServiceModel> get services =>
      cache.services.values.toList();

  List<String> get availableServices {
    final names = services
        .where((service) => service.isActive)
        .map((service) => service.name)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();

    names.sort();
    return ['All', ...names];
  }

  @override
  void onInit() {
    super.onInit();

    _loadDefaultVehicle();
    setFilter('Today');

    ever(cache.activities, (_) => applyLocalFilters());
    ever(cache.vehicles, (_) => update());
    ever(cache.customers, (_) => update());
    ever(cache.services, (_) => update());

    applyLocalFilters();
  }

  void _loadDefaultVehicle() {
    final data = localStorage.read('default_vehicle');

    if (data == null) return;

    try {
      final vehicle = VehicleModel.fromMap(
        Map<String, dynamic>.from(data),
      );

      if (vehicle.id.isNotEmpty) {
        selectedVehicleIds.assignAll([vehicle.id]);
      }
    } catch (error) {
      debugPrint('Default vehicle error: $error');
    }
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;

    final now = DateTime.now();

    switch (filter) {
      case 'Today':
        filterStartDate.text = formatDate(now.dayStartTime);
        filterEndDate.text = formatDate(now.dayEndTime);
        break;

      case 'Week':
        final start = now.subtract(const Duration(days: 6));
        filterStartDate.text = formatDate(start.dayStartTime);
        filterEndDate.text = formatDate(now.dayEndTime);
        break;

      case 'Month':
        final start = DateTime(now.year, now.month, 1);
        filterStartDate.text = formatDate(start.dayStartTime);
        filterEndDate.text = formatDate(now.dayEndTime);
        break;

      case 'All':
        filterStartDate.clear();
        filterEndDate.clear();
        break;
    }

    applyLocalFilters();
  }

  void applyLocalFilters() {
    DateTime? start;
    DateTime? end;

    try {
      if (filterStartDate.text.isNotEmpty) {
        start = DateFormat(
          'yyyy-MM-dd HH:mm',
        ).parse(filterStartDate.text);
      }

      if (filterEndDate.text.isNotEmpty) {
        end = DateFormat(
          'yyyy-MM-dd HH:mm',
        ).parse(filterEndDate.text).add(
          const Duration(seconds: 59),
        );
      }
    } catch (error) {
      debugPrint('Date filter error: $error');
    }

    final query = nameSearchQuery.value.trim().toLowerCase();

    final filtered = allActivities.where((activity) {
      if (start != null && activity.createdAt.isBefore(start)) {
        return false;
      }

      if (end != null && activity.createdAt.isAfter(end)) {
        return false;
      }

      if (selectedVehicleIds.isNotEmpty &&
          !selectedVehicleIds.contains(activity.vehicleId)) {
        return false;
      }

      if (selectedCustomerIds.isNotEmpty &&
          !selectedCustomerIds.contains(activity.customerId)) {
        return false;
      }

      if (selectedStaffIds.isNotEmpty &&
          (activity.receivedBy == null ||
              !selectedStaffIds.contains(activity.receivedBy))) {
        return false;
      }

      if (query.isNotEmpty) {
        final customer = cache.customers[activity.customerId];

        final customerName =
            customer?.name.toLowerCase() ?? '';

        final customerPhone =
            customer?.phone.toLowerCase() ?? '';

        if (!customerName.contains(query) &&
            !customerPhone.contains(query)) {
          return false;
        }
      }

      if (selectedServiceFilter.value != 'All') {
        final service = cache.services[activity.serviceId];

        if (service?.name != selectedServiceFilter.value) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    activities.assignAll(filtered);

    if (selectedIndex.value != null &&
        selectedIndex.value! >= activities.length) {
      selectedIndex.value = null;
    }
  }

  List<ActivityModel> activitiesForSection( PaymentStatus section) {
    return activities.where((activity) {
      final amount = activity.amount;
      final paid = activity.paidAmount;

      switch (section) {
        case PaymentStatus.payed:
          return amount > 0 && paid >= amount;

        case PaymentStatus.due:
          return amount > 0 && paid <= 0;

        case PaymentStatus.partial:
          return amount > 0 && paid > 0 && paid < amount;
      }
    }).toList();
  }
  List<ActivityModel> filteredActivities() {
      return activities.toList();
  }

  void selectIndex(int? index) {
    selectedIndex.value = index;
  }

  void changePageIndex(int index) {
    if (index < 0 || index > 2) return;

    currentPageIndex.value = index;
    selectedIndex.value = null;
  }

  void clearFilter() {
    selectedVehicleIds.clear();
    selectedCustomerIds.clear();
    selectedStaffIds.clear();

    nameSearchQuery.value = '';
    selectedServiceFilter.value = 'All';

    setFilter('Today');

    selectedIndex.value = null;
  }

  void showAIdFilters() {
    Get.dialog(
      AlertDialog(
        title: const Text('Filter'),
        content: Obx(
              () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: selectedVehicleIds.isEmpty
                    ? 'All'
                    : selectedVehicleIds.first,
                items: [
                  const DropdownMenuItem(
                    value: 'All',
                    child: Text('All Vehicles'),
                  ),
                  ...vehicles.map(
                        (vehicle) => DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(vehicle.number),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null || value == 'All') {
                    selectedVehicleIds.clear();
                  } else {
                    selectedVehicleIds.assignAll([value]);
                  }

                  applyLocalFilters();
                },
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: availableServices.contains(
                  selectedServiceFilter.value,
                )
                    ? selectedServiceFilter.value
                    : 'All',
                items: availableServices
                    .map(
                      (service) => DropdownMenuItem(
                    value: service,
                    child: Text(service),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  selectedServiceFilter.value = value;
                  applyLocalFilters();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void showNameSearch() {
    final controller = TextEditingController(
      text: nameSearchQuery.value,
    );

    Get.dialog(
      AlertDialog(
        title: const Text('Search Customer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Name or phone',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameSearchQuery.value = '';
              applyLocalFilters();
              Get.back();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              nameSearchQuery.value = controller.text.trim();
              applyLocalFilters();
              Get.back();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void showServiceFilter() {
    Get.dialog(
      AlertDialog(
        title: const Text('Filter by Service'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: availableServices.map((service) {
              return ListTile(
                title: Text(service),
                trailing: selectedServiceFilter.value == service
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  selectedServiceFilter.value = service;
                  applyLocalFilters();
                  Get.back();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void showDateFilter() {
    Get.dialog(
      AlertDialog(
        title: const Text('Filter by Date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: filterOptions.map((filter) {
            return ListTile(
              title: Text(filter),
              trailing: selectedFilter.value == filter
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                setFilter(filter);
                Get.back();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<bool> updateDescription(
      ActivityModel activity,
      String description,
      ) async {
    final now = DateTime.now();

    final success = await firebaseService.updateRecord(
      'activities',
      activity.id,
      {
        'description': description,
        'updatedAt': now.toUtc().toIso8601String(),
      },
    );

    if (!success) return false;

    activity.description = description;
    activity.updatedAt = now;

    activities.refresh();

    return true;
  }

  String customerName(String customerId) =>
      cache.customers[customerId]?.name ?? '-';

  String vehicleNumber(String vehicleId) =>
      cache.vehicles[vehicleId]?.number ?? '-';

  String serviceName(String serviceId) =>
      cache.services[serviceId]?.name ?? '-';

  String userName(String? userId) {
    if (userId == null || userId.isEmpty) return '-';

    return cache.users[userId]?.fullname ?? '-';
  }

  double customerTotalDue(String customerId) {
    return allActivities
        .where(
          (activity) =>
      activity.customerId == customerId &&
          activity.dueAmount > 0,
    )
        .fold(
      0.0,
          (sum, activity) => sum + activity.dueAmount,
    );
  }

  String formatDate(DateTime dateTime) {
    return DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(dateTime);
  }

  String secondsToHHMMSS(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  int totalSecondsFor(List<ActivityModel> entries) {
    return entries.fold(
      0,
          (sum, entry) => sum + entry.duration,
    );
  }

  double totalAmountFor(List<ActivityModel> entries) {
    return entries.fold(
      0.0,
          (sum, entry) => sum + entry.amount,
    );
  }

  double totalPaidFor(List<ActivityModel> entries) {
    return entries.fold(
      0.0,
          (sum, entry) => sum + entry.paidAmount,
    );
  }

  double totalDueFor(List<ActivityModel> entries) {
    return entries.fold(
      0.0,
          (sum, entry) => sum + entry.dueAmount,
    );
  }

  @override
  void onClose() {
    filterStartDate.dispose();
    filterEndDate.dispose();
    super.onClose();
  }
}