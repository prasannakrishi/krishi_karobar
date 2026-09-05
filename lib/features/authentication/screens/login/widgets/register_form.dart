import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import 'package:krishi_karobar/utils/constants/colors.dart';
import 'package:krishi_karobar/utils/constants/sizes.dart';
import 'package:krishi_karobar/utils/constants/text_strings.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';

import '../../../controllers/login_controllers.dart';

class URegisterForm extends StatelessWidget {
  const URegisterForm({super.key});

  static const _userTypes = ['Driver', 'Supervisor', 'Staff', 'Admin'];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoginController>();

    return Form(
      key: controller.registerFormKey,
      child: Column(
        children: [
          const SizedBox(height: USizes.md),
          _confirmPassword(controller),
          _field(controller.name, 'Full Name', Iconsax.user),
          _field(controller.address, 'Full Address', Iconsax.location),
          _userType(controller),
        ],
      ),
    );
  }

  Widget _confirmPassword(LoginController controller) {
    return Obx(
      () => TextFormField(
        controller: controller.confirmpassword,
        obscureText: controller.hideConfirmPassword.value,
        decoration: CustomDecoration.uInputDecoration(
          prefixIcon: const Icon(Iconsax.password_check),
          labelText: 'conformpassword',
          suffixIcon: IconButton(
            icon: Icon(
              controller.hideConfirmPassword.value
                  ? Iconsax.eye_slash
                  : Iconsax.eye,
            ),
            onPressed: controller.hideConfirmPassword.toggle,
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: USizes.md),
      child: TextFormField(
        controller: controller,
        decoration: CustomDecoration.uInputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _userType(LoginController controller) {
    return Padding(
      padding: const EdgeInsets.only(top: USizes.md),
      child: Obx(
        () => DropdownButtonFormField<String>(
          value: _userTypes.contains(controller.selectedUserType.value)
              ? controller.selectedUserType.value
              : _userTypes.first,
          decoration: CustomDecoration.uInputDecoration(
            labelText: 'User Type',
            prefixIcon: const Icon(Iconsax.category),
          ),
          items: _userTypes
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              controller.selectedUserType.value = value;
            }
          },
        ),
      ),
    );
  }
}
