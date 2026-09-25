import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../models/models.dart';
import '../../../services/services.dart';
import '../../../utils/exceptions/app_exceptions.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../../../utils/helper/network_manager.dart';
import '../../../utils/popups/full_screen_loader.dart';
import '../screens/login/login_screen.dart';
import '../../navigarion/screen/main_screen.dart';

class LoginController extends GetxController {
  static LoginController get instance => Get.find();

  final SequenceService sequenceService = Get.find<SequenceService>();
  final FirebaseService firebaseService = FirebaseService();
  final GetStorage localStorage = GetStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  static UserModel loginUser = UserModel.empty();

  final loginFormKey = GlobalKey<FormState>();
  final registerFormKey = GlobalKey<FormState>();

  final rememberMe = true.obs;
  final hidePassword = true.obs;
  final hideConfirmPassword = true.obs;
  final isNewUser = false.obs;

  final phone = TextEditingController();
  final password = TextEditingController();
  final confirmpassword = TextEditingController();
  final name = TextEditingController();
  final address = TextEditingController();

  @override
  void onInit() {
    phone.text = localStorage.read('REMEMBER_ME_PHONE') ?? '';
    super.onInit();
  }

  String get firebaseEmail =>
      '${phone.text.replaceAll('+', '').trim()}@kkarobar.com';

  String get phoneNumber {
    final value = phone.text.trim();
    return value.startsWith('+977') ? value : '+977$value';
  }

  Future<void> phoneAndPasswordSignIn() async {
    if (!(loginFormKey.currentState?.validate() ?? false)) return;

    await _runAuth(() async {
      if (!await NetworkManager.instance.isConnected()) {
        throw Exception('Please connect to the internet to sign in.');
      }

      final credential = await _signInWithPassword();

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception('Authentication failed.');
      }

      await _completeAuthentication(firebaseUser);
    });
  }

  Future<UserCredential> _signInWithPassword() async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: firebaseEmail,
        password: password.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authError(e));
    }
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
          email: firebaseEmail,
          password: password.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        throw Exception(_authError(e));
      }

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception('Unable to create authentication account.');
      }

      final databaseId = _uuid.v4();
      final userUid = await sequenceService.generateSequence('U');
      final now = DateTime.now().toUtc();

      final newUser = UserModel(
        id: databaseId,
        uId: userUid,
        nId: '',
        fullname: name.text.trim(),
        phone: phoneNumber,
        permanentAddress: address.text.trim(),
        // Public self-registration ALWAYS creates a Guest account with no
        // role. An authorized admin must explicitly promote the user to
        // Organization/External + a role afterwards (spec section 9/12).
        userType: UserTypes.guest,
        roles: const [],
        status: 'active',
        createdAt: now,
      );

      // The authUsers mapping is written first: every rule on /users
      // resolves the writer through authUsers/{auth.uid}/recordId, so the
      // mapping has to exist before the business record is created.
      try {
        await firebaseService.saveRecord(
          'authUsers',
          firebaseUser.uid,
          {
            'recordId': databaseId,
            'status': 'active',
            'roles': {
              for (final role in UserRoles.values) role: false,
            },
          },
        );
      } catch (e) {
        await _auth.currentUser?.delete();
        throw Exception(AppException.messageOf(e));
      }

      try {
        await firebaseService.saveRecord(
          'users',
          databaseId,
          newUser.toMap(),
        );
      } catch (e) {
        await firebaseService.deleteRecord('authUsers', firebaseUser.uid);
        await _auth.currentUser?.delete();
        throw Exception(AppException.messageOf(e));
      }

      // Spec section 10.6/10.7: notify admins + audit the registration.
      // Sending the actual email happens server-side (Cloud Function
      // listening on 'notification_queue') - the client never talks to
      // an email provider directly (spec section 11).
      await AuditService.instance.log(
        action: 'user_registered',
        performedBy: databaseId,
        targetUserId: databaseId,
        newValue: {'userType': UserTypes.guest, 'roles': const []},
      );

      try {
        await firebaseService.saveRecord(
          'notification_queue',
          _uuid.v4(),
          {
            'type': 'new_guest_registration',
            'userId': databaseId,
            'fullname': newUser.fullname,
            'phone': newUser.phone,
            'registeredAt': now.toIso8601String(),
            'status': 'pending',
          },
        );
      } catch (e) {
        // Notifying admins must never block a completed registration.
        debugPrint('LoginController notification_queue: $e');
      }

      await _completeAuthentication(firebaseUser);
    });
  }

  Future<void> completePhoneAuthentication(
      User firebaseUser,
      ) async {
    await _completeAuthentication(firebaseUser);
  }

  Future<void> _completeAuthentication(
      User firebaseUser,
      ) async {
    final UserModel profile;

    try {
      profile = await UserProfileResolver().resolve(firebaseUser);
    } catch (e) {
      await _auth.signOut();
      throw Exception(AppException.messageOf(e));
    }

    loginUser = profile;

    // The cache service is always registered - screens resolve it through
    // DataCacheService.instance regardless of user type. For a Guest it
    // simply holds no business data.
    if (!Get.isRegistered<DataCacheService>()) {
      Get.put(DataCacheService());
    }

    await DataCacheService.instance.initializeForUser(profile);

    _saveSession();
    _savePhoneHistory();

    Get.offAll(() => const MainScreen());
  }

  void _saveSession() {
    localStorage.write('loggedIn', true);
    localStorage.write('userId', loginUser.id);

    if (!rememberMe.value) {
      localStorage.remove('REMEMBER_ME_PHONE');
      return;
    }

    localStorage.write(
      'REMEMBER_ME_PHONE',
      phone.text.trim(),
    );
  }

  void _savePhoneHistory() {
    final history = <String>{
      phone.text.trim(),
      ...List<String>.from(
        localStorage.read<List>('PHONE_HISTORY') ?? [],
      ),
    }.toList();

    localStorage.write('PHONE_HISTORY', history);
  }

  List<String> get phoneHistory =>
      List<String>.from(
        localStorage.read<List>('PHONE_HISTORY') ?? [],
      );

  Future<void> logout() async {
    try {
      UFullScreenLoader.startLoading();

      if (Get.isRegistered<DataCacheService>()) {
        await DataCacheService.instance.clearCache();
        Get.delete<DataCacheService>();
      }

      loginUser = UserModel.empty();

      localStorage.remove('loggedIn');
      localStorage.remove('userId');
      localStorage.remove('selectedOrganization');
      localStorage.remove('selectedVehicle');
      localStorage.remove('default_vehicle');

      await _auth.signOut();

      Get.offAll(() => const LoginScreen());
    } catch (e) {
      errorSnackBar(
        title: 'Logout Failed',
        message: _errorMessage(e),
      );
    } finally {
      UFullScreenLoader.stopLoading();
    }
  }

  Future<void> _runAuth(
      Future<void> Function() action,
      ) async {
    try {
      UFullScreenLoader.startLoading();
      await action();
    } catch (e) {
      errorSnackBar(
        title: 'Authentication Failed',
        message: _errorMessage(e),
      );
    } finally {
      UFullScreenLoader.stopLoading();
    }
  }

  String _errorMessage(Object error) {
    if (error is AppException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
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
      case 'invalid-email':
        return 'Invalid phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
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
    super.onClose();
  }
}