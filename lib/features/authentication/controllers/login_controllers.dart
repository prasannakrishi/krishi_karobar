
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/helper/helper_functions.dart';
import '../../../utils/helper/network_manager.dart';
import '../../../utils/popups/full_screen_loader.dart';
import '../../navigarion/screen/main_screen.dart';
import '../../../models/user_model.dart';
import '../../../services/data_cache_service.dart';

class LoginController extends GetxController{

  static LoginController get instance => Get.find();

  /// --- Services ---
  static final firebaseService = FirebaseService();
  static final localStorage = GetStorage();

  static UserModel loginUser = UserModel.empty();


  /// --- Form Keys ---
  final loginFormKey = GlobalKey<FormState>();
  final registerFormKey = GlobalKey<FormState>();

  /// --- Reactive Variables ---
  final rememberMe = true.obs;
  final hidePassword = true.obs;
  final hideConfirmPassword = true.obs;
  final isNewUser = false.obs;

  /// --- Dropdown User Type ---
  final selectedUserType = 'Staff'.obs;

  /// --- Text Controllers ---
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirmpassword = TextEditingController();
  final name = TextEditingController();
  final address = TextEditingController();
  final wadaNo = TextEditingController();
  final email = TextEditingController();


  @override
  void onInit() {
    phone.text = localStorage.read('REMEMBER_ME_PHONE') ?? '';
    password.text = localStorage.read('REMEMBER_ME_PASSWORD') ?? '';
    super.onInit();
  }

  /// Phone and Password SignIn
  Future<void> phoneAndPasswordSignIn() async {
    try {
      if (!loginFormKey.currentState!.validate()) {
        return;
      }
      UFullScreenLoader.startLoading();

      final isConnected = await NetworkManager.instance.isConnected();

      if (!isConnected) {
        // Offline Login Logic
        final savedPhone = localStorage.read('REMEMBER_ME_PHONE');
        final savedPassword = localStorage.read('REMEMBER_ME_PASSWORD');

        if (savedPhone != null && savedPassword != null &&
            savedPhone == phone.text.trim() &&
            savedPassword == password.text.trim()) {
          
          final userData = localStorage.read('login_user_data');
          if (userData != null) {
            loginUser = UserModel.fromMap(Map<String, dynamic>.from(userData));
          }

          await DataCacheService.instance.initCache();
          UFullScreenLoader.stopLoading();
          Get.offAll(() => const MainScreen());

        } else {
          UFullScreenLoader.stopLoading();
          UHelperFunctions.errorSnackBar(
            title: 'Login Failed',
            message: 'No saved user found. Please connect to internet.',
          );
        }
        return;
      }
      var getUser = (await firebaseService.getUserByPhone('+977${phone.text.trim()}'));

      if (getUser != null && getUser.password == password.text.trim()) {
        loginUser = getUser;
        if (rememberMe.value) {
          localStorage.write('REMEMBER_ME_PHONE', phone.text.trim());
          localStorage.write('REMEMBER_ME_PASSWORD', password.text.trim());
          localStorage.write('login_user_data', loginUser.toMap());
        }else {
          localStorage.remove('REMEMBER_ME_PHONE');
          localStorage.remove('REMEMBER_ME_PASSWORD');
          localStorage.remove('login_user_data');
        }

        final updatedHistory = {phone.text.trim(),
          ...List<String>.from(localStorage.read<List>('PHONE_HISTORY') ?? [])}.toList();
        localStorage.write('PHONE_HISTORY', updatedHistory);

        localStorage.write( 'login_user',loginUser.name);
        
        await DataCacheService.instance.initCache();
        UFullScreenLoader.stopLoading();
        Get.offAll(() => const MainScreen());

      } else {
        UFullScreenLoader.stopLoading();
        UHelperFunctions.errorSnackBar(
          title: 'Login Failed',
          message: 'Incorrect phone number or password.',
        );
        return;
      }
    } catch (e) {
      UFullScreenLoader.stopLoading();
      UHelperFunctions.errorSnackBar(
        title: 'Oh Snap!',
        message: e.toString(),
      );
    }
  }

  /// Register User
  Future<void> registerUser() async {
    try {

      if (!registerFormKey.currentState!.validate()) return;

      UFullScreenLoader.startLoading();
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        UFullScreenLoader.stopLoading();
        UHelperFunctions.errorSnackBar(title: 'No Internet', message: 'Please connect to the internet to register.');
        return; // Finally will stop loader
      }
      final user = await firebaseService.getUserByPhone('+977${phone.text.trim()}');
      if(user != null){
        UFullScreenLoader.stopLoading();
        UHelperFunctions.errorSnackBar(title: 'Dear, ${user.name} Phone Number Already Exists', message: 'Try Forget password.');
        return;
      }

      final isCustomer = selectedUserType.value != 'Staff';
      final createdAt = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));

      final newUser = UserModel(
        guid: const Uuid().v4(),
        uid: await firebaseService.generateUserId(
            address.text.trim(), wadaNo.text.trim()),
        name: name.text.trim(),
        email: email.text.trim(),
        phone: '+977${phone.text.trim()}',
        address: address.text.trim(),
        usertype: selectedUserType.value,
        roll: selectedUserType.value,
        password: password.text.trim(),
        isCustomer: isCustomer,
        createdAt: createdAt,
        createdBy: LoginController.loginUser.guid,
      );

      final success = await firebaseService.save(newUser);

      if (success) {
        UFullScreenLoader.stopLoading();
        loginUser = newUser;
        if (rememberMe.value) {
          localStorage.write('REMEMBER_ME_PHONE', phone.text.trim());
          localStorage.write('REMEMBER_ME_PASSWORD', password.text.trim());
          localStorage.write('login_user_data', loginUser.toMap());
        }
        await DataCacheService.instance.initCache();
        Get.offAll(() => const MainScreen());
        return;
      } else {


        UFullScreenLoader.stopLoading();
        UHelperFunctions.errorSnackBar(
          title: 'Registration Failed',
          message: 'Unable to create account. Try again.',
        );
        return;
      }
    } catch (e){
      UFullScreenLoader.stopLoading();
      UHelperFunctions.errorSnackBar(title: 'Oh Snap!', message: e.toString());
    }
  }

  void showPhoneNumberHistory() {
    // Read the list of unique phone numbers from storage.
    final List<String> phoneHistory = List<String>.from(localStorage.read<List>('PHONE_HISTORY') ?? []);

    if (phoneHistory.isEmpty) {
      return;
    }

    Get.defaultDialog(
      title: 'Select a Phone Number',
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: phoneHistory.length,
          itemBuilder: (context, index) {
            final number = phoneHistory[index];
            return ListTile(
              title: Text(number),
              leading: const Icon(Icons.phone_android_outlined),
              onTap: () {
                phone.text = number;
                Get.back();
              },
            );
          },
        ),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('    Cancel    '),
      ),
    );
  }
  void showPhoneNumber() {
    final List<String> phoneHistory =
    List<String>.from(localStorage.read<List>('PHONE_HISTORY') ?? []);

    if (phoneHistory.isEmpty) {
      return;
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(5), // tighter padding
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select a Phone Number',
                style: Get.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade700,
                ),
              ),
              const SizedBox(height: 8), // minimal spacing
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: phoneHistory.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final number = phoneHistory[index];
                    return ListTile(
                      leading: const Icon(Icons.phone_android_outlined,
                          color: Colors.blueGrey),
                      title: Text(number),
                      onTap: () {
                        phone.text = number;
                        Get.back();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8), // minimal spacing
              Center(
                child: TextButton.icon(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }
  @override
  void onClose() {
    phone.dispose();
    password.dispose();
    confirmpassword.dispose();
    name.dispose();
    address.dispose();
    wadaNo.dispose();
    email.dispose();
    super.onClose();
  }

}
