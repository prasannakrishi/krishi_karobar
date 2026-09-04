import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:krishi_karobar/features/authentication/screens/login/widgets/register_form.dart';
import 'package:krishi_karobar/utils/constants/colors.dart';
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
        color: Colors.white.withAlpha(240),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: SingleChildScrollView(
          child: Form(
            key: controller.loginFormKey,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dynamic Welcome Header
                  Obx(() => Column(
                    children: [
                      Text(
                        controller.isNewUser.value ? UTexts.welcomeRegTitle : UTexts.welcomeLoginTitle,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: UColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        controller.isNewUser.value ? UTexts.welcomeRegSubTitle : UTexts.welcomeLoginSubTitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  )),
                  const SizedBox(height: 20),

                  /// Phone Number Label & Input
                  TextFormField(
                    controller: controller.phone,
                    keyboardType: TextInputType.phone,
                    onTap: () { controller.showPhoneNumber(); },
                    decoration: CustomDecoration.uInputDecoration(
                      prefixIcon: const Icon(Iconsax.call),
                      prefixText: '+977 ',
                      labelText: UTexts.phoneNo
                    ),
                  ),
                  const SizedBox( height: 20),

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
                          onPressed: () => controller.hidePassword.value = !controller.hidePassword.value
                        )
                      )
                    )
                  ),
                  
                  /// Toggleable Form View (Register/Login)
                  Obx(() {
                    if (controller.isNewUser.value) {
                      return URegisterForm(key: const ValueKey('RegisterView'));
                    } else {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Obx(() => Checkbox(
                                  value: controller.rememberMe.value,
                                  activeColor: UColors.primary,
                                  onChanged: (value) => controller.rememberMe.value = value ?? false,
                                )),
                              ),
                              const SizedBox(width: 8),
                              const Text("Remember me", style: TextStyle(fontSize: 14)),
                            ],
                          ),
                          TextButton(
                            onPressed: () => Get.to(() => const ForgetPassScreen()),
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(color: UColors.primary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      );
                    }
                  }),

                  const SizedBox(height: 15),

                  /// Sign In or Register Button
                  Obx(() => SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: controller.isNewUser.value
                          ? () => controller.registerUser()
                          : () => controller.phoneAndPasswordSignIn(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UColors.primary,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            controller.isNewUser.value ? UTexts.registerAccount : UTexts.signIn,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  )),

                  const SizedBox(height: 10),

                  /// OR Separator
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Text("OR", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),

                  /// Dynamic Footer Text
                  Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        controller.isNewUser.value ? UTexts.footerRegText : UTexts.footerCreateText,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      TextButton(
                        onPressed: () => controller.isNewUser.toggle(),
                        child: Text(
                          controller.isNewUser.value ? UTexts.footerRegTextBtn : UTexts.footerCreateTextBtn,
                          style: const TextStyle(color: UColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


