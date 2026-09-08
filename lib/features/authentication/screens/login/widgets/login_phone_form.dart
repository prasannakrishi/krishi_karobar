import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:krishi_karobar/features/authentication/screens/login/widgets/phone_history_dialog.dart';
import 'package:krishi_karobar/utils/constants/colors.dart';
import 'package:krishi_karobar/utils/constants/sizes.dart';
import 'package:krishi_karobar/utils/constants/text_strings.dart';
import 'package:krishi_karobar/utils/helper/helper_widgets.dart';
import 'package:krishi_karobar/utils/helper/network_manager.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';

class ULoginPhoneForm extends StatefulWidget {
  const ULoginPhoneForm({super.key});

  @override
  State<ULoginPhoneForm> createState() => _ULoginPhoneFormState();
}

class _ULoginPhoneFormState extends State<ULoginPhoneForm> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _otpController = TextEditingController();

  final _isCodeSent = false.obs;
  final _isLoading = false.obs;

  String _verificationId = '';
  int? _resendToken;
  bool _isCompleting = false;

  LoginController get _loginController => Get.find<LoginController>();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String _phoneNumber() {
    return _loginController.phone.text
        .trim()
        .replaceAll(RegExp(r'[\s-]'), '');
  }

  String _e164PhoneNumber() {
    return '+977${_phoneNumber()}';
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!await NetworkManager.instance.isConnected()) {
      errorSnackBar(
        title: 'No Internet',
        message: 'OTP login requires an internet connection.',
      );
      return;
    }

    _isLoading.value = true;

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _e164PhoneNumber(),
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          await _completeSignIn(credential);
        },
        verificationFailed: (error) {
          _isLoading.value = false;

          errorSnackBar(
            title: 'OTP Failed',
            message: _phoneAuthError(error),
          );
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isCodeSent.value = true;
          _isLoading.value = false;
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
          _isLoading.value = false;
        },
      );
    } catch (_) {
      _isLoading.value = false;

      errorSnackBar(
        title: 'OTP Failed',
        message: 'Unable to send verification code. Please try again.',
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_verificationId.isEmpty) {
      errorSnackBar(
        title: 'OTP Expired',
        message: 'Please request a new verification code.',
      );
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: _otpController.text.trim(),
    );

    await _completeSignIn(credential);
  }

  Future<void> _completeSignIn(
      AuthCredential credential,
      ) async {
    if (_isCompleting) return;

    _isCompleting = true;
    _isLoading.value = true;

    try {
      final result = await _auth.signInWithCredential(credential);

      final firebaseUser = result.user;

      if (firebaseUser == null) {
        throw Exception('Unable to verify phone number.');
      }

      await _loginController.completePhoneAuthentication(firebaseUser);
    } on FirebaseAuthException catch (error) {
      errorSnackBar(
        title: 'Login Failed',
        message: _phoneAuthError(error),
      );
    } catch (error) {
      errorSnackBar(
        title: 'Login Failed',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      _isCompleting = false;
      _isLoading.value = false;
    }
  }

  void _changePhoneNumber() {
    _verificationId = '';
    _resendToken = null;
    _otpController.clear();
    _isCodeSent.value = false;
  }

  String _phoneAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Enter a valid Nepali mobile number.';
      case 'invalid-verification-code':
        return 'The OTP is incorrect.';
      case 'session-expired':
        return 'OTP expired. Please request a new code.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'quota-exceeded':
        return 'Today’s SMS OTP quota has been reached.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return 'Phone verification failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      color: Colors.white.withAlpha(240),
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Form(
          key: _formKey,
          child: Obx(
                () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(context),
                const SizedBox(height: USizes.lg),
                _phoneField(),
                if (_isCodeSent.value) ...[
                  const SizedBox(height: USizes.md),
                  _otpField(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                      _isLoading.value ? null : _changePhoneNumber,
                      child: const Text('Change phone number'),
                    ),
                  ),
                ],
                const SizedBox(height: USizes.md),
                _submitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      children: [
        Text(
          'Login with OTP',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: UColors.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: USizes.xs),
        const Text(
          'Enter your mobile number to receive a verification code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _loginController.phone,
      keyboardType: TextInputType.phone,
      enabled: !_isCodeSent.value && !_isLoading.value,
      decoration: CustomDecoration.uInputDecoration(
        prefixIcon: const Icon(Iconsax.call),
        prefixText: '+977 ',
        labelText: UTexts.phoneNo,
      ),
      validator: (value) {
        final phone = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');

        if (!RegExp(r'^9\d{9}$').hasMatch(phone)) {
          return 'Enter a valid 10-digit mobile number.';
        }

        return null;
      },
      onTap: () {
        if (_loginController.phoneHistory.isEmpty) return;

        Get.dialog(
          UPhoneHistoryDialog(
            phoneHistory: _loginController.phoneHistory,
            onSelect: (value) {
              _loginController.phone.text = value;
            },
          ),
        );
      },
    );
  }

  Widget _otpField() {
    return TextFormField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      enabled: !_isLoading.value,
      decoration: CustomDecoration.uInputDecoration(
        prefixIcon: const Icon(Iconsax.password_check),
        labelText: '6-digit OTP',
      ),
      validator: (value) {
        if (_isCodeSent.value &&
            !RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')) {
          return 'Enter the 6-digit OTP.';
        }

        return null;
      },
    );
  }

  Widget _submitButton() {
    final isLoading = _isLoading.value;
    final codeSent = _isCodeSent.value;

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : (codeSent ? _verifyOtp : _sendOtp),
        style: ElevatedButton.styleFrom(
          backgroundColor: UColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          codeSent ? 'Verify OTP & Sign In' : 'Send OTP',
          style: const TextStyle(
            color: Colors.white,
            fontSize: USizes.fontSizeLg,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}