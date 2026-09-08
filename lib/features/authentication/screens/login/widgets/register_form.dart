import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import 'package:krishi_karobar/utils/constants/sizes.dart';
import 'package:krishi_karobar/utils/constants/text_strings.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';

import '../../../controllers/login_controllers.dart';

class URegisterForm extends StatelessWidget {
  const URegisterForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoginController>();

    return Column(
      children: [
        const SizedBox(height: USizes.md),
        _field(
          controller.name,
          'Full Name',
          Iconsax.user,
          required: true,
        ),
        _field(
          controller.address,
          'Full Address',
          Iconsax.location,
          required: true,
        ),
        _field(
          controller.email,
          'Email',
          Iconsax.sms,
        ),
        _confirmPassword(controller),
      ],
    );
  }

  Widget _field(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool required = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(top: USizes.md),
      child: TextFormField(
        controller: controller,
        keyboardType: label == 'Email'
            ? TextInputType.emailAddress
            : TextInputType.text,
        decoration: CustomDecoration.uInputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';

          if (required && text.isEmpty) {
            return '$label is required.';
          }

          if (label == 'Email' && text.isNotEmpty && !GetUtils.isEmail(text)) {
            return 'Enter a valid email address.';
          }

          return null;
        },
      ),
    );
  }

  Widget _confirmPassword(LoginController controller) {
    return Padding(
      padding: const EdgeInsets.only(top: USizes.md),
      child: Obx(
            () => TextFormField(
          controller: controller.confirmpassword,
          obscureText: controller.hideConfirmPassword.value,
          decoration: CustomDecoration.uInputDecoration(
            prefixIcon: const Icon(Iconsax.password_check),
            labelText: UTexts.confirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                controller.hideConfirmPassword.value
                    ? Iconsax.eye_slash
                    : Iconsax.eye,
              ),
              onPressed: controller.hideConfirmPassword.toggle,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Confirm password is required.';
            }

            if (value != controller.password.text) {
              return 'Passwords do not match.';
            }

            return null;
          },
        ),
      ),
    );
  }
}