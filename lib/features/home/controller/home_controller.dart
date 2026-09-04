import 'package:get/get.dart';
import 'package:krishi_karobar/models/user_model.dart';

class HomeController extends GetxController {
  static HomeController get instance => Get.find();


  // --- State Variables ---
  var isLoading = false.obs;
  final Rx<UserModel?> user = Rx<UserModel?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchUserData();
  }

  /// Fetches user data from Firebase.
  Future<void> fetchUserData() async {
    try {
      isLoading.value = true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch user data: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }
}
