import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../models/models.dart';
import '../../../services/services.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../../../utils/helper/network_manager.dart';
import '../../../utils/popups/full_screen_loader.dart';
import '../../navigarion/screen/main_screen.dart';

class LoginController extends GetxController {
  static LoginController get instance => Get.find();

  final SequenceService sequenceService = Get.find<SequenceService>();
  final FirebaseService firebaseService = FirebaseService();
  final GetStorage localStorage = GetStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static UserModel loginUser = UserModel.empty();

  final loginFormKey = GlobalKey<FormState>();
  final registerFormKey = GlobalKey<FormState>();

  final rememberMe = true.obs;
  final hidePassword = true.obs;
  final hideConfirmPassword = true.obs;
  final isNewUser = false.obs;
  final selectedUserType = 'Staff'.obs;

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

  String _getFirebaseEmail(String phoneNumber) {
    return '${phoneNumber.replaceAll('+', '').trim()}@kkarobar.com';
  }

  Future<void> phoneAndPasswordSignIn() async {
    if (!(loginFormKey.currentState?.validate() ?? false)) return;

    await _runAuth(() async {
      if (!await NetworkManager.instance.isConnected()) {
        return _offlineLogin();
      }

      try {
        await _auth.signInWithEmailAndPassword(
          email: _getFirebaseEmail(phone.text),
          password: password.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        throw _authError(e);
      }

      final user = DataCacheService.instance.getRecordByValue<UserModel>(
        'users',
        (item) => item.phone == '+977${phone.text.trim()}',
      );

      if (user == null) {
        throw Exception(
          'User authenticated but profile not found in database.',
        );
      }

      loginUser = user;
      _saveLoginData();
      _savePhoneHistory();

      Get.offAll(() => const MainScreen());
    });
  }

  Future<void> registerUser() async {
    if (!(registerFormKey.currentState?.validate() ?? false)) return;

    await _runAuth(() async {
      if (!await NetworkManager.instance.isConnected()) {
        throw Exception('Please connect to the internet to register.');
      }

      UserCredential credential;

      try {
        credential = await _auth.createUserWithEmailAndPassword(
          email: _getFirebaseEmail(phone.text),
          password: password.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        throw _authError(e);
      }

      final now = DateTime.now().toUtc();

      final newUser = UserModel(
        id: credential.user?.uid ?? '',
        uId: await sequenceService.generateSequence('U'),
        fullname: name.text.trim(),
        email: email.text.trim().isEmpty ? null : email.text.trim(),
        phone: '+977${phone.text.trim()}',
        permanentAddress: address.text.trim(),
        temporaryAddress: address.text.trim(),
        userType: selectedUserType.value,
        roles: [],
        status: 'active',
        createdAt: now,
      );

      if (newUser.id.isEmpty) {
        throw Exception('Unable to create user record ID.');
      }

      final success = await firebaseService.saveRecord(
        'users',
        newUser.id,
        newUser.toMap(),
      );

      if (!success) {
        throw Exception('Account created but profile could not be saved.');
      }

      loginUser = newUser;
      _saveLoginData();
      _savePhoneHistory();

      Get.offAll(() => const MainScreen());
    });
  }

  Future<void> _offlineLogin() async {
    final savedPhone = localStorage.read('REMEMBER_ME_PHONE');
    final savedPassword = localStorage.read('REMEMBER_ME_PASSWORD');

    if (savedPhone != phone.text.trim() ||
        savedPassword != password.text.trim()) {
      throw Exception('No saved user found. Please connect to internet.');
    }

    final userData = localStorage.read('login_user_data');

    if (userData == null) {
      throw Exception('No saved user data found. Please connect to internet.');
    }

    loginUser = UserModel.fromMap(Map<String, dynamic>.from(userData));

    Get.offAll(() => const MainScreen());
  }

  void _saveLoginData() {
    if (!rememberMe.value) {
      localStorage.remove('REMEMBER_ME_PHONE');
      localStorage.remove('REMEMBER_ME_PASSWORD');
      localStorage.remove('login_user_data');
      return;
    }

    localStorage.write('REMEMBER_ME_PHONE', phone.text.trim());
    localStorage.write('REMEMBER_ME_PASSWORD', password.text.trim());
    localStorage.write('login_user_data', loginUser.toMap());
  }

  void _savePhoneHistory() {
    final history = <String>{
      phone.text.trim(),
      ...List<String>.from(localStorage.read<List>('PHONE_HISTORY') ?? []),
    }.toList();

    localStorage.write('PHONE_HISTORY', history);
    localStorage.write('login_user', loginUser.fullname);
  }

  List<String> get phoneHistory =>
      List<String>.from(localStorage.read<List>('PHONE_HISTORY') ?? []);

  Future<void> _runAuth(Future<void> Function() action) async {
    try {
      UFullScreenLoader.startLoading();
      await action();
    } catch (e) {
      errorSnackBar(
        title: 'Login Failed',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      UFullScreenLoader.stopLoading();
    }
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'User not found.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect phone number or password.';
      case 'email-already-in-use':
        return 'This phone number is already registered.';
      case 'weak-password':
        return 'The password is too weak.';
      default:
        return 'Authentication failed.';
    }
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
