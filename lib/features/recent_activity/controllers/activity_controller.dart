import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:krishi_karobar/services/data_cache_service.dart';
import 'package:krishi_karobar/services/firebase_service.dart';
import 'package:krishi_karobar/utils/constants/enums.dart';
import 'package:krishi_karobar/utils/helper/helper_method.dart';
import '../../../models/models.dart';
import '../../authentication/controllers/login_controllers.dart';

class ActivityController extends GetxController {
  static ActivityController get instance => Get.find();

  final firebaseService = FirebaseService();
  final localStorage = GetStorage();

  final filterStartDate = TextEditingController();
  final filterEndDate = TextEditingController();
  
  final activities = <ActivityModel>[].obs;
  final allFetchedActivities = <ActivityModel>[];

  bool dateAscending = false;
  ActivityModel selectedEntry =  ActivityModel.empty();

  final isLoading = false.obs;
  final selectedIndex = RxnInt(null);
  
  final currentPageIndex = 1.obs; 
  bool isSyncing = false;

  final selectedFilter = 'Today'.obs;
  final filterOptions = ['Today', 'Week', 'Month', 'All'];

  final nameSearchQuery = ''.obs;
  final selectedServiceFilter = 'All'.obs;
  final availableServices = <String>['All'].obs;
  
  final vehicles = <VehicleModel>[].obs;
  final users = <UserModel>[].obs;
  final customers = <CustomerModel>[].obs;
  
  final selectedVehicleGuids = <String>[].obs;
  final selectedStaffGuids = <String>[].obs;
  final selectedCustomerGuids = <String>[].obs;

  final sections = ['Paid', 'Due', 'Partial'];
  final columnNames = ['AId', 'Name', 'Duration', 'Amount', 'Created On'];


  @override
  void onInit() {
    super.onInit();
    loadFilterMetadata();
    loadDefaultVehicleFromSettings();
    loadCachedActivities(); 
    syncWithFirebase();      
    setFilter('Today');
  }

  void loadCachedActivities() {
    final cached = localStorage.read<List>('cached_activities');
    if (cached != null) {
      allFetchedActivities.clear();
      for (var item in cached) {
        try {
          allFetchedActivities.add(ActivityModel.fromMap(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint("Cache parse error: $e");
        }
      }
      applyLocalFilters();
    }
  }

  Future<void> syncWithFirebase() async {
    try {
      isLoading.value = true;
      final activityList = await firebaseService.getRecords<ActivityModel>('activities');
      allFetchedActivities.clear();
      allFetchedActivities.addAll(activityList);
      
      // Save to cache
      localStorage.write('cached_activities', allFetchedActivities.map((e) => e.toMap()).toList());

      // Update available services
      final services = allFetchedActivities
          .map((e) => DataCacheService.instance.getServiceName(e.serviceType))
          .toSet()
          .toList();
      availableServices.assignAll(['All', ...services]);

      applyLocalFilters();
    } catch (e) {
      debugPrint("Sync error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void showAIdFilters() {
    Get.dialog(
      AlertDialog(
        title: const Text('Filter by Vehicle & Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Vehicle:', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() {
                final currentVehicle = selectedVehicleGuids.isEmpty ? 'All' : selectedVehicleGuids.first;
                // Ensure the value exists in the items list
                final exists = currentVehicle == 'All' || vehicles.any((v) => v.guid == currentVehicle);
                final dropdownValue = exists ? currentVehicle : 'All';
                
                return DropdownButton<String>(
                  isExpanded: true,
                  value: dropdownValue,
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text('All Vehicles')),
                    ...vehicles.map((v) => DropdownMenuItem(value: v.guid, child: Text(v.number))),
                  ],
                  onChanged: (val) {
                    if (val == 'All') {
                      selectedVehicleGuids.clear();
                    } else {
                      selectedVehicleGuids.assignAll([val!]);
                    }
                    applyLocalFilters();
                  },
                );
              }),
              const SizedBox(height: 16),
              const Text('Select Service:', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() {
                final currentService = selectedServiceFilter.value;
                final exists = availableServices.contains(currentService);
                final dropdownValue = exists ? currentService : 'All';
                
                return DropdownButton<String>(
                  isExpanded: true,
                  value: dropdownValue,
                  items: availableServices.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      selectedServiceFilter.value = val;
                      applyLocalFilters();
                    }
                  },
                );
              }),

            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
        ],
      ),
    );
  }

  void showNameSearch() {
    final textController = TextEditingController(
      text: nameSearchQuery.value,
    );

    Get.dialog(
      AlertDialog(
        title: const Text('Search by Name'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name...',
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
              nameSearchQuery.value = textController.text.trim();
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
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableServices.length,
            itemBuilder: (context, index) {
              final service = availableServices[index];

              return ListTile(
                title: Text(service),
                trailing: selectedServiceFilter.value == service
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  selectedServiceFilter.value = service;
                  applyLocalFilters();
                  Get.back();
                },
              );
            },
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
                  ? const Icon(Icons.check, color: Colors.blue)
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

  void loadDefaultVehicleFromSettings() {
    final defaultVehicleData = localStorage.read('default_vehicle');
    selectedVehicleGuids.clear(); 
    if (defaultVehicleData != null) {
      final v = VehicleModel.fromMap(Map<String, dynamic>.from(defaultVehicleData));
      selectedVehicleGuids.add(v.guid);
    }
  }

  Future<void> loadFilterMetadata() async {
    try {
      final vList = await firebaseService.getAllVehicles();
      vehicles.assignAll(vList);
      
      final uList = await firebaseService.getAllUsers();
      users.assignAll(uList.toList());

      final cList = await firebaseService.getAllCustomers();
      customers.assignAll(cList);
    } catch (e) {
      debugPrint("Metadata load error: $e");
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
        final weekStart = now.subtract(const Duration(days: 7));
        filterStartDate.text = formatDate(weekStart.dayStartTime);
        filterEndDate.text = formatDate(now.dayEndTime);
        break;
      case 'Month':
        final monthStart = DateTime(now.year, now.month, 1);
        filterStartDate.text = formatDate(monthStart.dayStartTime);
        filterEndDate.text = formatDate(now.dayEndTime);
        break;
      case 'All':
        filterStartDate.text = '';
        filterEndDate.text = '';
        break;
    }
    applyLocalFilters();
  }

  List<ActivityModel> activitiesForSection(PaymentStatus section) {
    switch (section) {
      case PaymentStatus.payed:
        return activities.where((e) => e.paidAmount >= e.amount && e.amount > 0).toList();
      case PaymentStatus.due:
        return activities.where((e) => e.paidAmount <= 0 && e.amount > 0).toList();
      case PaymentStatus.partial:
        return activities.where((e) => e.paidAmount > 0 && e.paidAmount < e.amount).toList();
    }
  }

  void selectIndex(int? index) {
    selectedIndex.value = index;
  }

  void changePageIndex(int newIndex) {
    if (newIndex >= 0 && newIndex <= 2) {
      currentPageIndex.value = newIndex;
      selectedIndex.value = null;
    }
  }

  void clearFilter() {
    selectedVehicleGuids.clear();
    selectedCustomerGuids.clear();
    setFilter('Today');
    selectedIndex.value = null;
  }

  Future<void> updatePaidStatus(ActivityModel entry, int newTotalPaid) async {
    if (newTotalPaid < 0 || newTotalPaid > entry.amount) {
      Get.snackbar('Error', 'Invalid amount.');
      return;
    }

    try {
      final int updatedDueAmount = (entry.amount - newTotalPaid).clamp(0, entry.amount);
      final DateTime now = DateTime.now();

      final Map<String, dynamic> updateData = {
        'paidAmount': newTotalPaid,
        'dueAmount': updatedDueAmount,
        'paidAt': now.toIso8601String(),
        'receivedBy': LoginController.loginUser.guid,
        'updatedAt': now.toIso8601String(),
      };

      final success = await firebaseService.updateRecord(updateData, 'activities', entry.guid);

      if (success) {
        entry.paidAmount = newTotalPaid;
        entry.dueAmount = updatedDueAmount;
        entry.paidAt = now;
        entry.receivedBy = LoginController.loginUser.guid;
        entry.updatedAt = now;
        
        activities.refresh(); 
        Get.snackbar('Updated', 'Payment saved successfully.');
        selectIndex(null);
      }
    } catch (e) {
      Get.snackbar('Sync Error', 'Could not update: $e');
    }
  }

  String formatDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }



  void applyLocalFilters() {
    DateTime? start;
    DateTime? end;
    try {
      if (filterStartDate.text.isNotEmpty) {
        start = DateFormat('yyyy-MM-dd HH:mm').parse(filterStartDate.text);
      }
      if (filterEndDate.text.isNotEmpty) {
        // Add 59 seconds to make it inclusive of the entire last minute
        end = DateFormat('yyyy-MM-dd HH:mm').parse(filterEndDate.text).add(const Duration(seconds: 59));
      }
    } catch (e) {
      debugPrint("Date parse error: $e");
    }


    var filtered = allFetchedActivities.where((activity) {
      // Date Filter
      if (start != null && activity.createdAt.isBefore(start)) return false;
      if (end != null && activity.createdAt.isAfter(end)) return false;

      // Allow showing all if no specific vehicles are selected
      bool matchesVehicle = selectedVehicleGuids.isEmpty || selectedVehicleGuids.contains(activity.vehicle);
      
      bool matchesStaff = selectedStaffGuids.isEmpty || (activity.receivedBy != null && selectedStaffGuids.contains(activity.receivedBy!));
      bool matchesCustomer = selectedCustomerGuids.isEmpty || selectedCustomerGuids.contains(activity.customer);
      // New Column Filters
      bool matchesName = nameSearchQuery.isEmpty || 
          DataCacheService.instance.getCustomerName(activity.customer).toLowerCase().contains(nameSearchQuery.value.toLowerCase());
      bool matchesService = selectedServiceFilter.value == 'All' || 
          DataCacheService.instance.getServiceName(activity.serviceType) == selectedServiceFilter.value;

      return matchesVehicle && matchesStaff && matchesCustomer && matchesName && matchesService;
    }).toList();

    activities.assignAll(filtered);
    activities.refresh();
  }


  int parseDurationToSeconds(String hhmmss) {
    if (hhmmss.trim().isEmpty) return 0;
    final parts = hhmmss.split(':').map((p) => p.trim()).toList();
    try {
      if (parts.length == 3) {
        return (int.tryParse(parts[0]) ?? 0) * 3600 + 
               (int.tryParse(parts[1]) ?? 0) * 60 + 
               (double.tryParse(parts[2]) ?? 0).round();
      }
    } catch (_) {}
    return 0;
  }

  String secondsToHHMMSS(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  int totalSecondsFor(List<ActivityModel> entries) => entries.fold(0, (sum, e) => sum + parseDurationToSeconds(e.duration));
  int totalAmountFor(List<ActivityModel> entries) => entries.fold(0, (sum, e) => sum + e.amount);
  int totalPaidFor(List<ActivityModel> entries) => entries.fold(0, (sum, e) => sum + e.paidAmount);
  int totalDueFor(List<ActivityModel> entries) => totalAmountFor(entries) - totalPaidFor(entries);
}
