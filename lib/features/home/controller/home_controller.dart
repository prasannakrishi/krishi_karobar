import 'package:get/get.dart';

import '../../../models/models.dart';
import '../../../services/data_cache_service.dart';
import '../../authentication/controllers/login_controllers.dart';

class HomeController extends GetxController {
  static HomeController get instance => Get.find();

  DataCacheService get _cache => DataCacheService.instance;

  final user = Rx<UserModel?>(null);

  int get todayActivities {
    final now = DateTime.now();

    return _cache.activities.values.where((activity) {
      final date = activity.startTime.toLocal();

      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
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