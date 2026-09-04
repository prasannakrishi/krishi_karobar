import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:krishi_karobar/features/authentication/screens/login/widgets/register_form.dart';
import 'package:krishi_karobar/utils/constants/colors.dart';

import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../../../utils/theme/widget_themes/custom_decoration.dart';
import '../../../controllers/login_controllers.dart';
import '../../password_configuration/forget_passwrod.dart';

class ULoginForm extends StatelessWidget {
  const ULoginForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoginController>();
    return Center(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        margin: const EdgeInsets.all(USizes.defaultSpace),
        child: Form(
          key: controller.loginFormKey,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// Phone
                TextFormField(
                  controller: controller.phone,
                  keyboardType: TextInputType.phone,
                  onTap: () { controller.showPhoneNumber(); },
                  decoration: CustomDecoration.uInputDecoration(
                    prefixIcon: Icon(Iconsax.call),
                    prefixText: '+977 ',
                    labelText: UTexts.phoneNo
                  ),
                ),
                const SizedBox( height: USizes.spaceBtwInputFields),

                /// Password
                Obx(
                  () => TextFormField(
                  controller: controller.password,
                  obscureText: controller.hidePassword.value,
                  decoration: CustomDecoration.uInputDecoration(
                      prefixIcon: const Icon(Iconsax.password_check),
                      labelText: UTexts.password,
                      suffixIcon: IconButton(
                          icon: Icon(controller.hidePassword.value ? Iconsax.eye_slash : Iconsax.eye),
                          onPressed: () => controller.hidePassword.value = !controller.hidePassword.value))),
                ),
                /// Remember Me / Forget Password
                Obx(() {
                  if (controller.isNewUser.value) {
                    /// --- REGISTRATION VIEW ---
                    return URegisterForm(key: const ValueKey('RegisterView'));
                  } else {
                    return Column( key: const ValueKey('LoginOptions'),
                      children: [
                        /// Remember Me
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Obx(() =>
                                    Checkbox(
                                      value: controller.rememberMe.value,
                                      onChanged: (value) =>
                                      controller.rememberMe.value = value ?? false,
                                    )),
                                const Text(UTexts.rememberMe),
                              ],
                            ),
                            /// Forget Password
                            TextButton(
                              onPressed: () => Get.to(() => const ForgetPassScreen()),
                              child: const Text(UTexts.forgetPassword),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                }),
                /// New User
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('New User?'),
                    Obx(() => Switch(
                        value: controller.isNewUser.value,
                        onChanged: (value) => controller.isNewUser.value = value,
                      ),
                    ),
                  ],
                ),

                /// Sign In / OTP / Register Button
                Obx(() => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isNewUser.value
                        ? () => controller.registerUser()
                        : () => controller.phoneAndPasswordSignIn(),
                    child: Text(controller.isNewUser.value ? UTexts.registerAccount :
                    UTexts.signIn, style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: UColors.white,
                        letterSpacing: 2)),
                  ),
                )),
                const SizedBox(height: USizes.spaceBtwItems),
              ],
            ),
        ),
      ),
      ),
    );
  }
}