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
            child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: USizes.spaceBtwInputFields),
                child: Column(
                  children: [
                    // Conform Password
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
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Name')
                    ),
                    const SizedBox(height: USizes.spaceBtwInputFields),
                    /*Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                                controller: controller.address,
                                decoration: CustomDecoration.uInputDecoration( labelText: 'Full Address')
                            )
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                            width: 100,
                            child: TextFormField(
                                controller: controller.wadaNo,
                                decoration: CustomDecoration.uInputDecoration( labelText: 'Wada No',),
                                keyboardType: TextInputType.number)
                        ),
                      ],
                    ),
                    const SizedBox(height: USizes.spaceBtwInputFields),
                    TextFormField(
                        controller: controller.email,
                        decoration: CustomDecoration.uInputDecoration( labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress
                    ),
                     */
                    TextFormField(
                        controller: controller.address,
                        decoration: CustomDecoration.uInputDecoration( labelText: 'Full Address')
                    ),
                    const SizedBox(height: 16),

                    Obx(() => DropdownButtonFormField<String>(
                      initialValue: controller.selectedUserType.value,
                      decoration: CustomDecoration.uInputDecoration(labelText: 'User Type'),
                      items: ['Driver', 'Supervisor', 'Staff', 'Admin'].map((String value) {
                        return DropdownMenuItem<String>(
                            value: value, child: Text(value));
                      }).toList(),
                      onChanged: (newValue) => controller.selectedUserType.value = newValue!,
                    )),
                  ],
                )
            )
        )
    );
  }
}