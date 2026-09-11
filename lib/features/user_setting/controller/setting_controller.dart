import 'package:get/get.dart';
import '../../authentication/screens/login/login_screen.dart';

class SettingsController extends GetxController {
  static SettingsController get instance => Get.find();

  final isLoading = false.obs;
  final managementExpanded = false.obs;
  final preferencesExpanded = false.obs;

  void toggleManagement() {
    managementExpanded.toggle();
  }

  void togglePreferences() {
    preferencesExpanded.toggle();
  }

  void logout() {
    Get.offAll(() => const LoginScreen());
  }
}