import 'package:get/get.dart';

import '../../../models/models.dart';
import '../../../services/data_cache_service.dart';
import '../../../utils/helper/nepali_date_time.dart';
import '../../authentication/controllers/login_controllers.dart';

class HomeController extends GetxController {
  static HomeController get instance => Get.find();

  DataCacheService get _cache => DataCacheService.instance;

  final user = Rx<UserModel?>(null);

  int get todayActivities {
    // "Today" is the current Nepal Standard Time calendar day, not the
    // device's own timezone or calendar - matches everything else the app
    // shows in Nepal time.
    final today = toNepaliCalendar(DateTime.now());

    return _cache.activities.values.where((activity) {
      final date = toNepaliCalendar(activity.startTime);

      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;
  }

  int get totalCustomers => _cache.customers.length;
  int get totalVehicles => _cache.vehicles.length;
  int get totalServices => _cache.services.length;

  @override
  void onInit() {
    user.value = LoginController.loginUser;
    super.onInit();
  }
}