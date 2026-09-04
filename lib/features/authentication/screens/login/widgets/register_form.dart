import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../../../utils/theme/widget_themes/custom_decoration.dart';
import '../../../controllers/login_controllers.dart';

class URegisterForm extends StatelessWidget {
  const URegisterForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoginController>();
    return Material(
        color: Colors.transparent,
        child: Form(
            key: controller.registerFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Conform Password
                const SizedBox(height: USizes.spaceBtwInputFields),
                Obx(() => TextFormField(
                  controller: controller.confirmpassword,
                  obscureText: controller.hidePassword.value,
                  decoration: CustomDecoration.uInputDecoration(
                    prefixIcon: const Icon(Iconsax.password_check),
                    labelText: UTexts.conformpassword,
                    suffixIcon: IconButton(
                      icon: Icon(controller.hidePassword.value ? Iconsax.eye_slash : Iconsax.eye),
                      onPressed: () => controller.hideConfirmPassword.value = !controller.hideConfirmPassword.value)
                  )
                )),
                const SizedBox(height: USizes.spaceBtwInputFields),
                
                TextFormField(
                    controller: controller.name,
                    decoration: CustomDecoration.uInputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Iconsax.user))
                ),
                const SizedBox(height: USizes.spaceBtwInputFields),

                TextFormField(
                    controller: controller.address,
                    decoration: CustomDecoration.uInputDecoration(labelText: 'Full Address', prefixIcon: const Icon(Iconsax.location))
                ),
                const SizedBox(height: USizes.spaceBtwInputFields),
                Obx(() {
                  final items = ['Driver', 'Supervisor', 'Staff', 'Admin'];
                  final current = controller.selectedUserType.value;
                  final value = items.contains(current) ? current : items.first;
                  
                  return DropdownButtonFormField<String>(
                    decoration: CustomDecoration.uInputDecoration(labelText: 'User Type', prefixIcon: const Icon(Iconsax.category)),
                    items: items.map((String val) {
                      return DropdownMenuItem<String>(
                          value: val, child: Text(val));
                    }).toList(),
                    onChanged: (newValue) => controller.selectedUserType.value = newValue!,
                  );
                }),
              ],
            )
        )
    );

  }
}