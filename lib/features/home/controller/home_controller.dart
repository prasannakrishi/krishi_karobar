import 'package:get/get.dart';

import '../../../models/models.dart';
import '../../../services/data_cache_service.dart';
import '../../../utils/helper/nepali_date_time.dart';
import '../../authentication/controllers/login_controllers.dart';
import '../../user_setting/controller/vehicle_controller.dart';

class HomeController extends GetxController {
  static HomeController get instance => Get.find();

  DataCacheService get _cache => DataCacheService.instance;

  final user = Rx<UserModel?>(null);
  final selectedVehicleId = 'all'.obs;

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

    final initialVid = selectedVehicleId.value;
    if (!currentUser.hasAllVehicleAccess && assigned.length == 1) {
      selectedVehicleId.value = assigned.first.id;
    } else if (initialVid != 'all' && !_cache.vehicles.containsKey(initialVid)) {
      selectedVehicleId.value = 'all';
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

  List<ActivityModel> get _filteredActivities {
    var acts = _cache.activities.values
        .where((a) => a.status != ActivityStatus.cancelled);

    final currentUser = LoginController.loginUser;
    final assigned = assignedVehicles;
    if (!currentUser.hasAllVehicleAccess && assigned.length == 1) {
      return acts.where((a) => a.vehicleId == assigned.first.id).toList();
    }

    final vId = selectedVehicleId.value;
    if (vId != 'all') {
      acts = acts.where((a) => a.vehicleId == vId);
    }
    return acts.toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    final currentUser = LoginController.loginUser;
    final assigned = assignedVehicles;
    if (!currentUser.hasAllVehicleAccess && assigned.length == 1) {
      return _cache.expenses.values.where((e) => e.vehicleId == assigned.first.id).toList();
    }

    final vId = selectedVehicleId.value;
    if (vId == 'all') {
      return _cache.expenses.values.toList();
    }
    return _cache.expenses.values.where((e) => e.vehicleId == vId).toList();
  }

  // Daily (Today)
  double get dailyIncome {
    final today = toNepaliCalendar(DateTime.now());
    return _filteredActivities
        .where((a) {
          final d = toNepaliCalendar(a.startTime);
          return d.year == today.year && d.month == today.month && d.day == today.day;
        })
        .fold(0.0, (sum, a) => sum + a.paidAmount);
  }

  double get dailyExpense {
    final today = toNepaliCalendar(DateTime.now());
    return _filteredExpenses
        .where((e) {
          final d = toNepaliCalendar(e.date);
          return d.year == today.year && d.month == today.month && d.day == today.day;
        })
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // Weekly (Last 7 days)
  double get weeklyIncome {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _filteredActivities
        .where((a) => a.startTime.isAfter(weekAgo))
        .fold(0.0, (sum, a) => sum + a.paidAmount);
  }

  double get weeklyExpense {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _filteredExpenses
        .where((e) => e.date.isAfter(weekAgo))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // Monthly (This BS Month)
  double get monthlyIncome {
    final today = toNepaliCalendar(DateTime.now());
    return _filteredActivities
        .where((a) {
          final d = toNepaliCalendar(a.startTime);
          return d.year == today.year && d.month == today.month;
        })
        .fold(0.0, (sum, a) => sum + a.paidAmount);
  }

  double get monthlyExpense {
    final today = toNepaliCalendar(DateTime.now());
    return _filteredExpenses
        .where((e) {
          final d = toNepaliCalendar(e.date);
          return d.year == today.year && d.month == today.month;
        })
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // Yearly (This BS Year)
  double get yearlyIncome {
    final today = toNepaliCalendar(DateTime.now());
    return _filteredActivities
        .where((a) {
          final d = toNepaliCalendar(a.startTime);
          return d.year == today.year;
        })
        .fold(0.0, (sum, a) => sum + a.paidAmount);
  }

  double get yearlyExpense {
    final today = toNepaliCalendar(DateTime.now());
    return _filteredExpenses
        .where((e) {
          final d = toNepaliCalendar(e.date);
          return d.year == today.year;
        })
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  int get todayActivities {
    final today = toNepaliCalendar(DateTime.now());
    return _filteredActivities.where((a) {
      final d = toNepaliCalendar(a.startTime);
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).length;
  }
}
