import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/utils/helper/helper_widgets.dart';
import '/utils/helper/network_manager.dart';
import '/utils/popups/full_screen_loader.dart';
import '../screens/password_configuration/reset_password.dart';

class ForgetPasswordController extends GetxController {
  static ForgetPasswordController get instance => Get.find();

  final phone = TextEditingController();
  final forgetPasswordFormKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _getFirebaseEmail(String phoneNumber) {
    return '${phoneNumber.replaceAll('+', '').trim()}@kkarobar.com';
  }

  Future<void> sendPasswordResetEmail() async {
    if (!(forgetPasswordFormKey.currentState?.validate() ?? false)) return;

    try {
      UFullScreenLoader.startLoading();

      if (!await NetworkManager.instance.isConnected()) {
        throw Exception('Please connect to the internet.');
      }

      await _auth.sendPasswordResetEmail(email: _getFirebaseEmail(phone.text));

      Get.off(() => ResetPasswordScreen(phone: phone.text.trim()));
    } on FirebaseAuthException catch (e) {
      errorSnackBar(title: 'Password Reset Failed', message: _authError(e));
    } catch (e) {
      errorSnackBar(
        title: 'Oh Snap!',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      UFullScreenLoader.stopLoading();
    }
  }

  Future<void> resendPasswordResetEmail() async {
    try {
      UFullScreenLoader.startLoading();

      if (!await NetworkManager.instance.isConnected()) {
        throw Exception('Please connect to the internet.');
      }

      await _auth.sendPasswordResetEmail(email: _getFirebaseEmail(phone.text));

      successSnackBar(
        title: 'Email Sent',
        message: 'Password reset link has been sent.',
      );
    } on FirebaseAuthException catch (e) {
      errorSnackBar(title: 'Resend Failed', message: _authError(e));
    } catch (e) {
      errorSnackBar(
        title: 'Oh Snap!',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      UFullScreenLoader.stopLoading();
    }
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for this phone number.';
      case 'invalid-email':
        return 'Invalid phone number.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return 'Unable to send password reset email.';
    }
  }

  @override
  void onClose() {
    phone.dispose();
    super.onClose();
  }
}
