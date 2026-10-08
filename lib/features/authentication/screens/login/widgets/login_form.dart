import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import 'package:krishi_karobar/common/widgets/u_widgets.dart';
import 'package:krishi_karobar/features/authentication/screens/login/widgets/register_form.dart';
import 'package:krishi_karobar/features/authentication/screens/login/widgets/phone_history_dialog.dart';
import 'package:krishi_karobar/features/authentication/screens/password_configuration/forget_passwrod.dart';
import 'package:krishi_karobar/utils/constants/colors.dart';
import 'package:krishi_karobar/utils/constants/sizes.dart';
import 'package:krishi_karobar/utils/constants/text_strings.dart';

import '../../../controllers/login_controllers.dart';

class ULoginForm extends StatelessWidget {
  const ULoginForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoginController>();

    return Card(
      elevation: 5,
      color: Colors.white.withValues(alpha: 240 / 255),
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(
          () => Form(
            key: controller.isNewUser.value
                ? controller.registerFormKey
                : controller.loginFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _welcomeHeader(controller, context),
                const SizedBox(height: USizes.lg),
                _phoneField(controller),
                const SizedBox(height: USizes.md),
                _passwordField(controller),
                if (controller.isNewUser.value)
                  const URegisterForm()
                else
                  _loginOptions(controller),
                const SizedBox(height: USizes.md),
                _submitButton(controller),
                const SizedBox(height: USizes.sm),
                _divider(),
                _switchAccountMode(controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomeHeader(
    LoginController controller,
    BuildContext context,
  ) {
    return Column(
      children: [
        Text(
          controller.isNewUser.value
              ? UTexts.welcomeRegTitle
              : UTexts.welcomeLoginTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: UColors.primary,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: USizes.xs),
        Text(
          controller.isNewUser.value
              ? UTexts.welcomeRegSubTitle
              : UTexts.welcomeLoginSubTitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _phoneField(LoginController controller) {
    return UTextField(
      controller: controller.phone,
      keyboardType: TextInputType.phone,
      prefixIcon: const Icon(Iconsax.call),
      prefixText: '+977 ',
      labelText: UTexts.phoneNo,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Phone number is required.';
        }

        if (value.trim().length < 10) {
          return 'Enter a valid phone number.';
        }

        return null;
      },
      onTap: () {
        if (controller.phoneHistory.isEmpty) return;

        Get.dialog(
          UPhoneHistoryDialog(
            phoneHistory: controller.phoneHistory,
            onSelect: (value) {
              controller.phone.text = value;
            },
          ),
        );
      },
    );
  }

  Widget _passwordField(LoginController controller) {
    return Obx(
      () => UTextField(
        controller: controller.password,
        obscureText: controller.hidePassword.value,
        prefixIcon: const Icon(Iconsax.password_check),
        labelText: UTexts.password,
        suffixIcon: IconButton(
          icon: Icon(
            controller.hidePassword.value
                ? Iconsax.eye_slash
                : Iconsax.eye,
          ),
          onPressed: controller.hidePassword.toggle,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Password is required.';
          }

          if (controller.isNewUser.value && value.length < 6) {
            return 'Password must be at least 6 characters.';
          }

          return null;
        },
      ),
    );
  }

  Widget _loginOptions(LoginController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Obx(
              () => Checkbox(
                value: controller.rememberMe.value,
                activeColor: UColors.primary,
                onChanged: (value) {
                  controller.rememberMe.value = value ?? false;
                },
              ),
            ),
            const Text(UTexts.rememberMe),
          ],
        ),
        TextButton(
          onPressed: () => Get.to(
            () => const ForgetPassScreen(),
          ),
          child: const Text(
            UTexts.forgetPassword,
            style: TextStyle(
              color: UColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _submitButton(LoginController controller) {
    return UButton(
      text: controller.isNewUser.value
          ? UTexts.registerAccount
          : UTexts.signIn,
      style: UButtonStyle.primary,
      isFullWidth: true,
      icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
      onPressed: controller.isNewUser.value
          ? controller.registerUser
          : controller.phoneAndPasswordSignIn,
    );
  }

  Widget _divider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.grey.shade300),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: USizes.sm),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: Colors.grey.shade300),
        ),
      ],
    );
  }

  Widget _switchAccountMode(LoginController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          controller.isNewUser.value
              ? UTexts.footerRegText
              : UTexts.footerCreateText,
        ),
        TextButton(
          onPressed: controller.isNewUser.toggle,
          child: Text(
            controller.isNewUser.value
                ? UTexts.footerRegTextBtn
                : UTexts.footerCreateTextBtn,
            style: const TextStyle(
              color: UColors.primary,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
