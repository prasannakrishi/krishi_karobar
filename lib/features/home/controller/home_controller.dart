import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:nepali_utils/nepali_utils.dart';

import '../../../models/models.dart';
import '../../../services/data_cache_service.dart';
import '../../../utils/exceptions/app_exceptions.dart';
import '../../../utils/helper/nepali_date_time.dart';
import '../../../utils/helper/network_manager.dart';
import '../../../offline/offline_storage.dart';
import '../../../offline/core/workspace_access_user.dart';
import '../../authentication/controllers/login_controllers.dart';
import '../../user_setting/controller/vehicle_controller.dart';
import '../../user_setting/screen/customer_management_screen.dart';
import '../../user_setting/screen/profile_screen.dart';
import '../../recent_activity/controllers/activity_controller.dart';
import '../../recent_activity/screen/widgets/expense_form_dialog.dart';
import '../../navigarion/controller/navigation_controller.dart';

class VehiclePerformanceItem {
  final String vehicleId;
  final String vehicleNumber;
  final int activitiesCount;
  final double serviceAmount;
  final double dueAmount;

  VehiclePerformanceItem({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.activitiesCount,
    required this.serviceAmount,
    required this.dueAmount,
  });
}

class HomeController extends GetxController {
  static HomeController get instance => Get.find();

  DataCacheService get _cache => DataCacheService.instance;

  final user = Rx<UserModel?>(null);
  final selectedVehicleId = 'all'.obs;
  final selectedPeriod = 'Today'.obs; // 'Today', 'Week', 'Month', 'All'
  final pendingQueueCount = 0.obs;
  final pendingQueueError = RxnString();
  final offlineStatusMessage = RxnString();

  final List<String> periodOptions = ['Today', 'Week', 'Month', 'All'];

  @override
  void onInit() {
    super.onInit();
    final currentUser = LoginController.loginUser;
    user.value = currentUser;

    final assigned = assignedVehicles;

    if (!currentUser.hasAllVehicleAccess && assigned.length == 1) {
      selectedVehicleId.value = assigned.first.id;
    } else if (Get.isRegistered<VehicleController>()) {
      final defaultVeh = VehicleController.instance.selectedVehicle.value;
      if (defaultVeh != null && defaultVeh.id.isNotEmpty) {
        if (_cache.vehicles.containsKey(defaultVeh.id)) {
          selectedVehicleId.value = defaultVeh.id;
        }
      }
      ever(VehicleController.instance.selectedVehicle, (veh) {
        if (currentUser.hasAllVehicleAccess || assigned.length > 1) {
          if (veh != null && veh.id.isNotEmpty) {
            if (_cache.vehicles.containsKey(veh.id)) {
              selectedVehicleId.value = veh.id;
            } else {
              selectedVehicleId.value = 'all';
            }
          }
        }
      });
    }

    if (!currentUser.hasAllVehicleAccess && assigned.length == 1) {
      selectedVehicleId.value = assigned.first.id;
    }

    ever(_cache.vehicles, (_) {
      final currentUserCheck = LoginController.loginUser;
      final assignedCheck = assignedVehicles;
      if (!currentUserCheck.hasAllVehicleAccess && assignedCheck.length == 1) {
        selectedVehicleId.value = assignedCheck.first.id;
        return;
      }
      final vId = selectedVehicleId.value;
      if (vId != 'all' && !_cache.vehicles.containsKey(vId)) {
        selectedVehicleId.value = 'all';
      }
    });

    // Bi-directional sync with ActivityController date filter
    if (Get.isRegistered<ActivityController>()) {
      selectedPeriod.value = ActivityController.instance.selectedFilter.value;
      ever(ActivityController.instance.selectedFilter, (filter) {
        if (selectedPeriod.value != filter) {
          selectedPeriod.value = filter;
        }
      });
    }

    ever(selectedPeriod, (period) {
      if (Get.isRegistered<ActivityController>()) {
        final actCtrl = Get.find<ActivityController>();
        if (actCtrl.selectedFilter.value != period) {
          actCtrl.setFilter(period);
        }
      }
    });

    // Auto sync when online connectivity resumes
    if (Get.isRegistered<NetworkManager>()) {
      ever(NetworkManager.instance.connectionStatus, (status) {
        if (status != ConnectivityResult.none) {
          triggerSync();
        }
      });
    }

    // Open the workspace (with the owner's access profile) once now - the
    // initial vehicle was chosen above, so `ever` alone would never fire for
    // a user whose vehicle does not change - and again whenever the
    // dashboard's selected vehicle changes.
    ever(selectedVehicleId, (_) => _activateOfflineWorkspace());
    _activateOfflineWorkspace();
  }

  bool _activatingWorkspace = false;
  bool _activationRequestedAgain = false;

  /// One activation at a time per controller: a request that arrives while
  /// one is running (startup, then a vehicle change) is coalesced into a
  /// single follow-up run instead of overlapping it. Not a permanent lock -
  /// every call still reaches the repository, which serializes them.
  Future<void> _activateOfflineWorkspace() async {
    if (_activatingWorkspace) {
      _activationRequestedAgain = true;
      return;
    }
    _activatingWorkspace = true;
    try {
      do {
        _activationRequestedAgain = false;
        await _activateOfflineWorkspaceOnce();
      } while (_activationRequestedAgain);
    } finally {
      _activatingWorkspace = false;
    }
  }

  Future<void> _activateOfflineWorkspaceOnce() async {
    if (!OfflineStorage.isAvailable) {
      _reportOfflineUnavailable();
      return;
    }
    final currentUser = LoginController.loginUser;
    if (currentUser.id.isEmpty) return;

    // One workspace per owner. The selected vehicle is not part of its
    // identity; re-opening it refreshes the owner's access profile.
    try {
      final scope = OfflineStorage.currentScope(
        vehicleId: selectedVehicleId.value,
      );
      await OfflineStorage.instance.activateWorkspace(
        scope,
        ownerPhone: currentUser.phone,
        access: workspaceAccessFor(
          currentUser,
          ownedVehicleIds: _cache.vehicles.values
              .where((vehicle) => vehicle.ownerId == currentUser.id)
              .map((vehicle) => vehicle.id),
        ),
      );
      offlineStatusMessage.value = null;
    } catch (e, stack) {
      offlineStatusMessage.value = AppException.messageOf(e);
      debugPrint('HomeController _activateOfflineWorkspace failed: $e\n$stack');
    }
    await _checkPendingQueue();
  }

  static bool _offlineNoticeShown = false;

  void _reportOfflineUnavailable() {
    final reason = OfflineStorage.unavailableReason;
    offlineStatusMessage.value = reason;
    if (reason == null || _offlineNoticeShown) return;
    _offlineNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Get.snackbar(
          'Offline storage unavailable',
          '$reason Changes cannot be saved on this device until it is fixed.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (e) {
        debugPrint('HomeController offline notice not shown: $e');
      }
    });
  }

  Future<void> _checkPendingQueue() async {
    if (!OfflineStorage.isAvailable) return;
    try {
      final counts = await OfflineStorage.instance.pendingCounts();
      pendingQueueCount.value = counts.unsynced;
      pendingQueueError.value = null;
    } catch (e, stack) {
      // Keep the last known count; a failed read must not look like "0".
      pendingQueueError.value = AppException.messageOf(e);
      debugPrint('HomeController pending queue count failed: $e\n$stack');
    }
  }

  /// Refresh dashboard data
  Future<void> refreshDashboard() async {
    await _checkPendingQueue();
  }

  /// Manual / Tap sync trigger
  Future<void> triggerSync() async {
    try {
      if (OfflineStorage.isAvailable) {
        await OfflineStorage.instance.syncNow();
      }
    } catch (e) {
      debugPrint('HomeController triggerSync notice: $e');
    }
    await refreshDashboard();
  }

  /// Update selected vehicle filter
  void setSelectedVehicle(String? vehicleId) {
    if (vehicleId != null) {
      selectedVehicleId.value = vehicleId;
    }
  }

  /// Update selected period filter (syncs with ActivityController)
  void setSelectedPeriod(String? period) {
    if (period != null) {
      selectedPeriod.value = period;
      if (Get.isRegistered<ActivityController>()) {
        final actCtrl = Get.find<ActivityController>();
        if (actCtrl.selectedFilter.value != period) {
          actCtrl.setFilter(period);
        }
      }
    }
  }

  bool get canSwitchVehicle {
    final u = LoginController.loginUser;
    if (u.hasAllVehicleAccess) return true;
    return assignedVehicles.length > 1;
  }

  List<VehicleModel> get assignedVehicles {
    final u = LoginController.loginUser;
    if (u.hasAllVehicleAccess) {
      final seen = <String>{};
      return _cache.vehicles.values.where((v) => seen.add(v.id)).toList();
    }
    return _cache.vehicles.values.where((v) =>
        v.ownerId == u.id || u.assignedVehicleIds.contains(v.id)).toList();
  }

  List<VehicleModel> get vehicles => assignedVehicles;
  int get totalCustomers => _cache.customers.length;
  int get totalVehicles => _cache.vehicles.length;
  int get totalServices => _cache.services.length;

  VehicleModel? get selectedVehicle {
    if (selectedVehicleId.value == 'all') return null;
    return _cache.vehicles[selectedVehicleId.value];
  }

  String get assignedVehicleDetailsText {
    final assigned = assignedVehicles;
    if (assigned.isEmpty) return 'No Assigned Vehicle';
    if (selectedVehicleId.value != 'all') {
      final v = _cache.vehicles[selectedVehicleId.value];
      if (v != null) return '${v.number} (${v.name} • ${v.vehicleType})';
    }
    return assigned.map((v) => '${v.number} (${v.vehicleType})').join(', ');
  }

  DateTime? get _calculatedFilterStart {
    final todayNepali = toNepaliCalendar(DateTime.now());
    final todayCalendarDay = NepaliDateTime(
      todayNepali.year,
      todayNepali.month,
      todayNepali.day,
    ).toDateTime();

    switch (selectedPeriod.value) {
      case 'Today':
        return nepalCalendarDayBoundary(todayCalendarDay);
      case 'Week':
        final start = todayCalendarDay.subtract(const Duration(days: 6));
        return nepalCalendarDayBoundary(start);
      case 'Month':
        final bsMonthStart = NepaliDateTime(
          todayNepali.year,
          todayNepali.month,
          1,
        ).toDateTime();
        return nepalCalendarDayBoundary(bsMonthStart);
      case 'All':
      default:
        return null;
    }
  }

  DateTime? get _calculatedFilterEnd {
    final todayNepali = toNepaliCalendar(DateTime.now());
    final todayCalendarDay = NepaliDateTime(
      todayNepali.year,
      todayNepali.month,
      todayNepali.day,
    ).toDateTime();

    switch (selectedPeriod.value) {
      case 'Today':
      case 'Week':
      case 'Month':
        return nepalCalendarDayBoundary(todayCalendarDay, endOfDay: true);
      case 'All':
      default:
        return null;
    }
  }

  bool _isDateInFilter(DateTime date) {
    final start = _calculatedFilterStart;
    final end = _calculatedFilterEnd;
    if (start == null || end == null) return true;
    return (date.isAtSameMomentAs(start) || date.isAfter(start)) &&
        (date.isAtSameMomentAs(end) || date.isBefore(end));
  }

  List<ActivityModel> get _filteredActivities {
    var acts = _cache.activities.values
        .where((a) => a.status != ActivityStatus.cancelled);

    final currentUser = LoginController.loginUser;
    final assigned = assignedVehicles;
    if (!currentUser.hasAllVehicleAccess && assigned.length == 1) {
      acts = acts.where((a) => a.vehicleId == assigned.first.id);
    } else {
      final vId = selectedVehicleId.value;
      if (vId != 'all') {
        acts = acts.where((a) => a.vehicleId == vId);
      }
    }

    return acts.where((a) => _isDateInFilter(a.createdAt)).toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    var exps = _cache.expenses.values.where((e) => e.status != 'cancelled');

    final currentUser = LoginController.loginUser;
    final assigned = assignedVehicles;
    if (!currentUser.hasAllVehicleAccess && assigned.length == 1) {
      exps = exps.where((e) => e.vehicleId == assigned.first.id);
    } else {
      final vId = selectedVehicleId.value;
      if (vId != 'all') {
        exps = exps.where((e) => e.vehicleId == vId);
      }
    }

    return exps.where((e) => _isDateInFilter(e.createdAt)).toList();
  }

  // Financial summary getters
  double get totalServiceAmount {
    return _filteredActivities.fold(0.0, (sum, a) => sum + a.amount);
  }

  double get amountCollected {
    return _filteredActivities.fold(0.0, (sum, a) => sum + a.paidAmount);
  }

  double get outstandingDue {
    return _filteredActivities.fold(0.0, (sum, a) => sum + a.dueAmount);
  }

  double get totalExpenses {
    return _filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
  }

  double get operatingResult {
    return totalServiceAmount - totalExpenses;
  }

  int get totalActivitiesCount {
    return _filteredActivities.length;
  }

  double get dailyIncome => _filteredActivities.fold(0.0, (s, a) => s + a.paidAmount);
  double get dailyExpense => _filteredExpenses.fold(0.0, (s, e) => s + e.amount);
  double get weeklyIncome => dailyIncome;
  double get weeklyExpense => dailyExpense;
  double get monthlyIncome => dailyIncome;
  double get monthlyExpense => dailyExpense;
  double get yearlyIncome => dailyIncome;
  double get yearlyExpense => dailyExpense;

  int get todayActivities {
    final today = toNepaliCalendar(DateTime.now());
    return _cache.activities.values
        .where((a) => a.status != ActivityStatus.cancelled)
        .where((a) {
          final d = toNepaliCalendar(a.createdAt);
          return d.year == today.year && d.month == today.month && d.day == today.day;
        })
        .length;
  }

  int get todayRunningActivities {
    final today = toNepaliCalendar(DateTime.now());
    return _cache.activities.values
        .where((a) => a.status == ActivityStatus.running)
        .where((a) {
          final d = toNepaliCalendar(a.createdAt);
          return d.year == today.year && d.month == today.month && d.day == today.day;
        })
        .length;
  }

  int get todayCompletedActivities {
    final today = toNepaliCalendar(DateTime.now());
    return _cache.activities.values
        .where((a) => a.status == ActivityStatus.completed)
        .where((a) {
          final d = toNepaliCalendar(a.createdAt);
          return d.year == today.year && d.month == today.month && d.day == today.day;
        })
        .length;
  }

  int get todayDueActivities {
    final today = toNepaliCalendar(DateTime.now());
    return _cache.activities.values
        .where((a) => a.dueAmount > 0 && a.status != ActivityStatus.cancelled)
        .where((a) {
          final d = toNepaliCalendar(a.createdAt);
          return d.year == today.year && d.month == today.month && d.day == today.day;
        })
        .length;
  }

  List<VehiclePerformanceItem> get vehiclePerformanceList {
    final items = <VehiclePerformanceItem>[];
    final activeVehicles = assignedVehicles;

    for (final v in activeVehicles) {
      final vActs = _cache.activities.values
          .where((a) => a.vehicleId == v.id && a.status != ActivityStatus.cancelled)
          .where((a) => _isDateInFilter(a.createdAt))
          .toList();

      final count = vActs.length;
      final servAmt = vActs.fold(0.0, (s, a) => s + a.amount);
      final dueAmt = vActs.fold(0.0, (s, a) => s + a.dueAmount);

      items.add(VehiclePerformanceItem(
        vehicleId: v.id,
        vehicleNumber: v.number,
        activitiesCount: count,
        serviceAmount: servAmt,
        dueAmount: dueAmt,
      ));
    }

    return items;
  }

  double get totalCustomerDue {
    return _cache.activities.values
        .where((a) => a.status != ActivityStatus.cancelled)
        .fold(0.0, (s, a) => s + a.dueAmount);
  }

  int get customersWithDueCount {
    final customerIdsWithDue = _cache.activities.values
        .where((a) => a.dueAmount > 0 && a.status != ActivityStatus.cancelled)
        .map((a) => a.customerId)
        .toSet();
    return customerIdsWithDue.length;
  }

  /// Recent Activities: Most recent 1 record for each vehicle
  List<ActivityModel> get recentActivities {
    final Map<String, ActivityModel> latestPerVehicle = {};

    final acts = _cache.activities.values
        .where((a) => a.status != ActivityStatus.cancelled)
        .toList();

    acts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final act in acts) {
      if (!latestPerVehicle.containsKey(act.vehicleId)) {
        latestPerVehicle[act.vehicleId] = act;
      }
    }

    final result = latestPerVehicle.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  bool get isOffline {
    if (!Get.isRegistered<NetworkManager>()) return false;
    return NetworkManager.instance.connectionStatus.value == ConnectivityResult.none;
  }

  String get loginUserName {
    final u = LoginController.loginUser;
    return u.fullname.isNotEmpty ? u.fullname : 'Admin';
  }

  String get syncStatusText {
    if (isOffline) return 'Offline';
    if (pendingQueueCount.value > 0) return 'Waiting (${pendingQueueCount.value})';
    return 'Online • Synced';
  }

  Color get syncStatusColor {
    if (isOffline) return Colors.amber.shade800;
    if (pendingQueueCount.value > 0) return Colors.orange.shade800;
    return Colors.green;
  }

  Color get syncStatusBgColor {
    if (isOffline) return Colors.amber.withValues(alpha: 0.2);
    if (pendingQueueCount.value > 0) return Colors.orange.withValues(alpha: 0.2);
    return Colors.green.withValues(alpha: 0.15);
  }

  String get currentNepaliDateFormatted {
    return formatNepaliDate(DateTime.now(), pattern: 'yyyy MMMM d, EEEE');
  }

  String get userInitial {
    final name = LoginController.loginUser.fullname;
    if (name.isNotEmpty) return name[0].toUpperCase();
    return 'A';
  }

  // Quick Action handlers
  void onNavigateToMonitor() {
    if (Get.isRegistered<NavigationController>()) {
      Get.find<NavigationController>().onTabSelected(1);
    }
  }

  void onNavigateToRecords() {
    if (Get.isRegistered<NavigationController>()) {
      Get.find<NavigationController>().onTabSelected(2);
    }
  }

  void onNavigateToCustomers() {
    Get.to(() => CustomerManagementScreen());
  }

  void onOpenAddExpense() {
    Get.dialog(const ExpenseFormDialog());
  }

  void openNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  _notificationItem('Activity Started', 'Vehicle operation started successfully.', '10m ago'),
                  _notificationItem('Payment Received', 'Collection recorded for recent activity.', '1h ago'),
                  _notificationItem('System Synced', 'All offline records synchronized with server.', '3h ago'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationItem(String title, String subtitle, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE8F5E9),
            child: Icon(Icons.notifications, color: Color(0xFF1B5E20), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  void openProfile() {
    Get.to(() => const ProfileScreen());
  }
}
