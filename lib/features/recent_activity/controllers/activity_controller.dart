import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:nepali_utils/nepali_utils.dart';

import '../../../models/models.dart';
import '../../../features/authentication/controllers/login_controllers.dart';
import '../../../features/user_setting/controller/vehicle_controller.dart';
import '../../../services/data_cache_service.dart';
import '../../../services/authorization_service.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/exceptions/app_exceptions.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/helper/nepali_date_time.dart';
import '../../../offline/offline_storage.dart';
import '../screen/widgets/edit_activity_dialog.dart';
import '../screen/widgets/expense_form_dialog.dart';
import '../screen/widgets/activity_form_dialog.dart';

class ActivityController extends GetxController {
  static ActivityController get instance => Get.find();

  final firebaseService = FirebaseService();
  final localStorage = GetStorage();
  final cache = DataCacheService.instance;

  DateTime? _filterStart;
  DateTime? _filterEnd;

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

  final sections = ['Paid', 'Due', 'Expenses'];

  List<ActivityModel> get allActivities =>
      cache.activities.values
          .where((activity) => activity.status != ActivityStatus.cancelled)
          .toList();

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
    ever(cache.expenses, (_) {
      applyLocalFilters();
      update();
    });
    ever(cache.vehicles, (_) {
      _loadDefaultVehicle();
      update();
    });
    ever(cache.customers, (_) => update());
    ever(cache.services, (_) => update());

    if (Get.isRegistered<VehicleController>()) {
      ever(VehicleController.instance.selectedVehicle, (vehicle) {
        if (vehicle != null && vehicle.id.isNotEmpty) {
          selectedVehicleIds.assignAll([vehicle.id]);
          applyLocalFilters();
        }
      });
    }

    applyLocalFilters();
  }

  void _loadDefaultVehicle() {
    if (Get.isRegistered<VehicleController>()) {
      final selected = VehicleController.instance.selectedVehicle.value;
      if (selected != null && selected.id.isNotEmpty) {
        selectedVehicleIds.assignAll([selected.id]);
        return;
      }
    }

    final user = LoginController.loginUser;
    final recentId = user.recentVehicleIds?.trim();
    if (recentId != null && recentId.isNotEmpty) {
      final recentVehicle = vehicles.firstWhereOrNull((v) => v.id == recentId);
      if (recentVehicle != null) {
        selectedVehicleIds.assignAll([recentVehicle.id]);
        return;
      }
    }

    final assignedIds = user.assignedVehicleIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    if (assignedIds.isEmpty) {
      selectedVehicleIds.clear();
      return;
    }

    final assignedVehicle = vehicles.firstWhereOrNull(
      (vehicle) =>
          assignedIds.contains(vehicle.id) && vehicle.isActive,
    );

    if (assignedVehicle != null) {
      selectedVehicleIds.assignAll([assignedVehicle.id]);
      return;
    }

    selectedVehicleIds.clear();
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;

    // "Today"/"Week"/"Month" are always the Nepal Standard Time, Bikram
    // Sambat calendar day/month - this app only operates in Nepal, so the
    // device's own timezone or calendar never decides these boundaries.
    final todayNepali = toNepaliCalendar(DateTime.now());
    final todayCalendarDay = NepaliDateTime(
      todayNepali.year,
      todayNepali.month,
      todayNepali.day,
    ).toDateTime();

    switch (selectedFilter.value) {
      case 'Today':
        _filterStart = nepalCalendarDayBoundary(todayCalendarDay);
        _filterEnd = nepalCalendarDayBoundary(
          todayCalendarDay,
          endOfDay: true,
        );
        break;

      case 'Week':
        final start = todayCalendarDay.subtract(const Duration(days: 6));
        _filterStart = nepalCalendarDayBoundary(start);
        _filterEnd = nepalCalendarDayBoundary(
          todayCalendarDay,
          endOfDay: true,
        );
        break;

      case 'Month':
        final bsMonthStart = NepaliDateTime(
          todayNepali.year,
          todayNepali.month,
          1,
        ).toDateTime();
        _filterStart = nepalCalendarDayBoundary(bsMonthStart);
        _filterEnd = nepalCalendarDayBoundary(
          todayCalendarDay,
          endOfDay: true,
        );
        break;

      case 'All':
        _filterStart = null;
        _filterEnd = null;
        break;
    }

    applyLocalFilters();
  }

  void applyLocalFilters() {
    final start = _filterStart;
    final end = _filterEnd;

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
            customer?.phone?.toLowerCase() ?? '';

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

  List<ActivityModel> activitiesForSection( ActivityState section) {
    return activities.where((activity) {
      final amount = activity.amount;
      final paid = activity.paidAmount;
      final discount = activity.discountAmount;
      final due = amount - (paid + discount);

      switch (section) {
        case ActivityState.payed:
          return due <= 0;  //amount > 0 &&

        case ActivityState.due:
          return due > 0; //amount > 0 &&

        case ActivityState.expences:
          return false;
      }
    }).toList();
  }

  final selectedExpenseTypeFilter = 'All'.obs;

  void showExpenseTypeFilter() {
    Get.dialog(
      AlertDialog(
        title: const Text('Filter by Expense Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['All', 'General', 'Vehicle', 'Activity Related'].map((type) {
            return ListTile(
              title: Text(type),
              trailing: selectedExpenseTypeFilter.value == type ? const Icon(Icons.check) : null,
              onTap: () {
                selectedExpenseTypeFilter.value = type;
                Get.back();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  List<ExpenseModel> get expensesList {
    final start = _filterStart;
    final end = _filterEnd;
    final query = nameSearchQuery.value.trim().toLowerCase();
    final typeFilter = selectedExpenseTypeFilter.value;

    final list = cache.expenses.values.where((exp) {
      if (exp.status == 'cancelled') return false;
      if (start != null && exp.createdAt.isBefore(start)) return false;
      if (end != null && exp.createdAt.isAfter(end)) return false;

      if (typeFilter != 'All' && exp.expenseType != typeFilter) return false;

      if (query.isNotEmpty) {
        if (!exp.uId.toLowerCase().contains(query) &&
            !exp.categoryName.toLowerCase().contains(query) &&
            !(exp.description?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }

      return true;
    }).toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void showAddExpenseDialog() {
    Get.dialog(const ExpenseFormDialog());
  }

  void showAddActivityDialog() {
    if (!Authz.can(Permissions.activityCreate)) {
      Get.snackbar('Permission Denied', 'You do not have permission to create activities.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    Get.dialog(const ActivityFormDialog());
  }

  void showEditExpenseDialog(ExpenseModel expense) {
    if (!Authz.can(Permissions.expenseEdit)) {
      Get.snackbar('Permission Denied', 'You do not have permission to edit expenses.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    Get.dialog(ExpenseFormDialog(expense: expense));
  }

  Future<void> confirmDeleteExpense(ExpenseModel expense) async {
    if (!Authz.can(Permissions.expenseDelete)) {
      Get.snackbar('Permission Denied', 'Only Admin can delete expenses.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to cancel/delete expense "${expense.uId}"?'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Get.back();
              try {
                final updateData = {
                  'status': 'cancelled',
                  'updatedAt': DateTime.now().toUtc().toIso8601String(),
                  'updatedBy': LoginController.loginUser.id,
                };
                await OfflineStorage.saveLocalOrThrow(
                  entityType: 'expenses',
                  recordId: expense.id,
                  data: updateData,
                  isNew: false,
                );
                Get.snackbar('Success', 'Expense cancelled successfully.', snackPosition: SnackPosition.BOTTOM);
              } catch (e) {
                Get.snackbar('Error', AppException.messageOf(e), snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

    try {
      Authz.requirePermission(Permissions.activityEdit);

      Authz.requireRecordAccess(
        Authz.canEditActivity(activity),
        recordType: 'activity',
        recordId: activity.id,
      );

      final patchData = {
        'description': description,
        'updatedAt': now.toUtc().toIso8601String(),
      };

      // A failed local save aborts: the outer catch shows the error, and
      // neither the model, the cache nor Firebase is changed.
      OfflineStorage.requireAvailable();
      await OfflineStorage.instance.localRecords.saveRecord(
        OfflineStorage.currentScope(vehicleId: activity.vehicleId),
        entityType: 'activities',
        recordId: activity.id,
        data: {...activity.toMap(), ...patchData},
        isNew: false,
        baseUpdatedAt: activity.updatedAt.toUtc().toIso8601String(),
      );

      activity.description = description;
      activity.updatedAt = now;

      final cached = cache.activities[activity.id];
      if (cached != null) {
        cached.description = description;
        cached.updatedAt = now;
      }
      activities.refresh();

      try {
        await firebaseService.updateRecord('activities', activity.id, patchData);
      } catch (e) {
        debugPrint('ActivityController firebase description sync notice: $e');
      }

      return true;
    } catch (e) {
      Get.snackbar(
        'Activity',
        AppException.messageOf(e),
        snackPosition: SnackPosition.BOTTOM,
      );
      debugPrint('ActivityController updateDescription: $e');
      return false;
    }
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

  int customerTotalDue(String customerId) {
    return allActivities.where((activity) =>activity.customerId == customerId
        &&activity.dueAmount > 0)
        .fold(0,(sum, activity) => sum + activity.dueAmount);
  }

  /// User-visible date - always Nepal Standard Time, Bikram Sambat.
  String formatDate(DateTime dateTime) {
    return formatNepaliDateTime(dateTime);
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
    return entries.fold(0,(sum, entry) => sum + entry.duration);
  }

  int totalAmountFor(List<ActivityModel> entries) {
    return entries.fold(0,(sum, entry) => (sum + entry.amount).toInt());
  }

  int totalPaidFor(List<ActivityModel> entries) {
    return entries.fold(0,(sum, entry) => (sum + entry.paidAmount).toInt());
  }
  int totalDiscountFor(List<ActivityModel> entries) {
      return entries.fold(0,(sum, entry) => (sum + entry.discountAmount).toInt());
    }

  int totalDueFor(List<ActivityModel> entries) {
    return entries.fold(0,(sum, entry) => (sum + entry.dueAmount).toInt());
  }

  List<String> get recentDescriptions {
    final uniqueDescriptions = <String>{};

    for (final activity in cache.activities.values) {
      final desc = activity.description?.trim();
      if (desc != null && desc.isNotEmpty) {
        uniqueDescriptions.add(desc);
      }
    }

    final list = uniqueDescriptions.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  void showEditActivityDialog(ActivityModel activity) {
    Get.dialog(
      EditActivityDialog(
        activity: activity,
        controller: this,
      ),
    );
  }

  Future<bool> updateActivity({
    required ActivityModel activity,
    required String customerId,
    required String vehicleId,
    required String serviceId,
    required int duration,
    required int rate,
    required int amount,
    required int paidAmount,
    required String description,
  }) async {
    final now = DateTime.now();
    final dueAmount = (amount - paidAmount) > 0 ? (amount - paidAmount) : 0;

    try {
      Authz.requirePermission(Permissions.activityEdit);

      final updateData = {
        'customerId': customerId,
        'vehicleId': vehicleId,
        'serviceId': serviceId,
        'duration': duration,
        'rate': rate,
        'amount': amount,
        'paidAmount': paidAmount,
        'dueAmount': dueAmount,
        'description': description,
        'updatedAt': now.toUtc().toIso8601String(),
      };

      // A failed local save aborts: the outer catch shows the error, and
      // neither the model, the cache nor Firebase is changed.
      OfflineStorage.requireAvailable();
      await OfflineStorage.instance.localRecords.saveRecord(
        OfflineStorage.currentScope(vehicleId: vehicleId),
        entityType: 'activities',
        recordId: activity.id,
        data: {...activity.toMap(), ...updateData},
        isNew: false,
        baseUpdatedAt: activity.updatedAt.toUtc().toIso8601String(),
      );

      activity.customerId = customerId;
      activity.vehicleId = vehicleId;
      activity.serviceId = serviceId;
      activity.duration = duration;
      activity.rate = rate;
      activity.amount = amount;
      activity.paidAmount = paidAmount;
      activity.dueAmount = dueAmount;
      activity.description = description;
      activity.updatedAt = now;

      final cached = cache.activities[activity.id];
      if (cached != null) {
        cached.customerId = customerId;
        cached.vehicleId = vehicleId;
        cached.serviceId = serviceId;
        cached.duration = duration;
        cached.rate = rate;
        cached.amount = amount;
        cached.paidAmount = paidAmount;
        cached.dueAmount = dueAmount;
        cached.description = description;
        cached.updatedAt = now;
        cache.activities[activity.id] = cached;
      }

      applyLocalFilters();
      activities.refresh();

      try {
        await firebaseService.updateRecord(
          'activities',
          activity.id,
          updateData,
        );
      } catch (e) {
        debugPrint('ActivityController firebase activity sync notice: $e');
      }

      Get.snackbar(
        'Success',
        'Activity updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return true;
    } catch (e) {
      Get.snackbar(
        'Activity',
        AppException.messageOf(e),
        snackPosition: SnackPosition.BOTTOM,
      );
      debugPrint('ActivityController updateActivity: $e');
      return false;
    }
  }

  void confirmDeleteActivity(ActivityModel activity) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Activity'),
        content: Text(
          'Are you sure you want to delete activity "${activity.uId}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Get.back();
              await deleteActivity(activity);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<bool> deleteActivity(ActivityModel activity) async {
    try {
      Authz.requirePermission(Permissions.activityEdit);

      final cancelData = {
        'status': ActivityStatus.cancelled,
        'cancelledBy': LoginController.loginUser.id,
        'cancelledAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await OfflineStorage.saveLocalOrThrow(
        entityType: 'activities',
        recordId: activity.id,
        data: cancelData,
        isNew: false,
      );

      final cached = cache.activities[activity.id];
      if (cached != null) {
        cached.status = ActivityStatus.cancelled;
        cached.cancelledBy = LoginController.loginUser.id;
        cached.cancelledAt = DateTime.now();
        cached.updatedAt = DateTime.now();
        cache.activities.refresh();
      }

      applyLocalFilters();
      selectedIndex.value = null;

      Get.snackbar(
        'Success',
        'Activity reset/cancelled successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return true;
    } catch (e) {
      Get.snackbar(
        'Activity',
        AppException.messageOf(e),
        snackPosition: SnackPosition.BOTTOM,
      );
      debugPrint('ActivityController deleteActivity: $e');
      return false;
    }
  }

}
