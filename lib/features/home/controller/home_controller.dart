import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../models/models.dart';
import '../../../services/data_cache_service.dart';

class HomeController extends GetxController {
  static HomeController get instance => Get.find();

  final DataCacheService _cache = DataCacheService.instance;
  final GetStorage _storage = GetStorage();
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
    super.onInit();
    loadUser();
  }

  void loadUser() {
    final data = _storage.read('login_user_data');

    if (data is Map) {
      user.value = UserModel.fromMap(
        Map<String, dynamic>.from(data),
      );
    }
  }
}