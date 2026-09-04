import 'package:get/get.dart';
import '../../authentication/screens/login/login_screen.dart';

class SettingsController extends GetxController {
  static SettingsController get instance => Get.find();

  /// --- State Variables ---
  var isLoading = false.obs;
  var toggleVehicleForm = false.obs;
  var toggleUserForm = false.obs;

  void toggleVehicleFormView() {
    toggleVehicleForm.value = !toggleVehicleForm.value;
  }
  void toggleUserFormView() {
    toggleUserForm.value = !toggleUserForm.value;
  }

  @override
  void onInit() {
    super.onInit();
    toggleVehicleForm.value = false;
    toggleUserForm.value = false;
  }

  /// Logs out the user and navigates to the Login screen.
  void logout() {
    Get.offAll(() => const LoginScreen());
  }
}