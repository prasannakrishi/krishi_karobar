import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../../../utils/helper/network_manager.dart';
import '../../../utils/popups/full_screen_loader.dart';
import '../../navigarion/screen/main_screen.dart';
import '../../../models/models.dart';
import '../../../services/data_cache_service.dart';

class LoginController extends GetxController{

  static LoginController get instance => Get.find();

  /// --- Services ---
  static final firebaseService = FirebaseService();
  static final localStorage = GetStorage();
  final _auth = FirebaseAuth.instance;

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

  /// Helper to get internal Firebase Email from Phone
  String _getFirebaseEmail(String phoneNumber) {
    // Standardize phone and append domain to use Email/Password Auth
    final cleanPhone = phoneNumber.replaceAll('+', '').trim();
    return "$cleanPhone@kkarobar.com";
  }

  /// Phone and Password SignIn using Firebase Auth
  Future<void> phoneAndPasswordSignIn() async {
    try {
      if (!loginFormKey.currentState!.validate()) {
        return;
      }
      UFullScreenLoader.startLoading();

      final isConnected = await NetworkManager.instance.isConnected();

      if (!isConnected) {
        // Offline Login Logic (Check local storage)
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
          errorSnackBar(
            title: 'Login Failed',
            message: 'No saved user found. Please connect to internet.',
          );
        }
        return;
      }

      // 1. Firebase Authentication
      final firebaseEmail = _getFirebaseEmail(phone.text.trim());
      
      try {
        await _auth.signInWithEmailAndPassword(
          email: firebaseEmail,
          password: password.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        UFullScreenLoader.stopLoading();
        String msg = 'Authentication failed.';
        if (e.code == 'user-not-found') {msg = 'User not found.';}
        else if (e.code == 'wrong-password') {msg = 'Incorrect password.';}
        
        errorSnackBar(title: 'Login Failed', message: msg);
        return;
      }

      // 2. Fetch User Model from Realtime Database
      var userModel = (await firebaseService.getUserByPhone('+977${phone.text.trim()}'));

      if (userModel != null) {
        loginUser = userModel;
        
        if (rememberMe.value) {
          localStorage.write('REMEMBER_ME_PHONE', phone.text.trim());
          localStorage.write('REMEMBER_ME_PASSWORD', password.text.trim());
          localStorage.write('login_user_data', loginUser.toMap());
        } else {
          localStorage.remove('REMEMBER_ME_PHONE');
          localStorage.remove('REMEMBER_ME_PASSWORD');
          localStorage.remove('login_user_data');
        }

        final updatedHistory = {phone.text.trim(),
          ...List<String>.from(localStorage.read<List>('PHONE_HISTORY') ?? [])}.toList();
        localStorage.write('PHONE_HISTORY', updatedHistory);

        localStorage.write( 'login_user',loginUser.fullname);
        
        await DataCacheService.instance.initCache();
        UFullScreenLoader.stopLoading();
        Get.offAll(() => const MainScreen());

      } else {
        UFullScreenLoader.stopLoading();
        errorSnackBar(
          title: 'Error',
          message: 'User authenticated but profile not found in database.',
        );
      }
    } catch (e) {
      UFullScreenLoader.stopLoading();
      errorSnackBar(
        title: 'Oh Snap!',
        message: e.toString(),
      );
    }
  }
  /// Register User using Firebase Auth
  Future<void> registerUser() async {
    try {
      if (!registerFormKey.currentState!.validate()) return;

      UFullScreenLoader.startLoading();
      final isConnected = await NetworkManager.instance.isConnected();
      if (!isConnected) {
        UFullScreenLoader.stopLoading();
        errorSnackBar(title: 'No Internet', message: 'Please connect to the internet to register.');
        return;
      }

      // 1. Create Account in Firebase Auth
      final firebaseEmail = _getFirebaseEmail(phone.text.trim());
      try {
        await _auth.createUserWithEmailAndPassword(
          email: firebaseEmail,
          password: password.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        UFullScreenLoader.stopLoading();
        String msg = 'Registration failed.';
        if (e.code == 'email-already-in-use') {msg = 'This phone number is already registered.';}
        else if (e.code == 'weak-password') {msg = 'The password is too weak.';}
        
        errorSnackBar(title: 'Registration Failed', message: msg);
        return;
      }

      // 2. Save User Profile in Realtime Database
      final createdAt = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));

      final newUser = UserModel(
        guid: _auth.currentUser?.uid ?? const Uuid().v4(), // Use Auth UID as GUID
        uid: await firebaseService.generateUserId(address.text.trim(), wadaNo.text.trim()),
        fullname: name.text.trim(),
        email: email.text.trim(),
        phone: '+977${phone.text.trim()}',
        permanentAddress: address.text.trim(),
        temporaryAddress: address.text.trim(),
        userType: null, // UserType is optional in model now
        roles: [], // Will be set by admin later or defaults
        status: UserStatus.active,
        createdAt: createdAt,
        createdBy: null, // System or self
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
      } else {
        UFullScreenLoader.stopLoading();
        errorSnackBar(
          title: 'Database Error',
          message: 'Account created but profile could not be saved. Please contact support.',
        );
      }
    } catch (e){
      UFullScreenLoader.stopLoading();
      errorSnackBar(title: 'Oh Snap!', message: e.toString());
    }
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
          padding: const EdgeInsets.all(5),
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
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
