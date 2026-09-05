import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/widgets/app_scaffold.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../controllers/forget_password_controller.dart';
import '../login/login_screen.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key, required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ForgetPasswordController>();

    return UAppScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: UColors.primary,
        actions: [
          IconButton(
            onPressed: Get.back,
            icon: const Icon(CupertinoIcons.clear),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(USizes.defaultSpace),
        child: Column(
          children: [
            Text(
              '+977 $phone',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: USizes.spaceBtwItems),
            Text(
              UTexts.changeYourPasswordTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: UColors.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: USizes.spaceBtwItems),
            Text(
              UTexts.changeYourPasswordSubTitle,
              style: Theme.of(context).textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: USizes.spaceBtwSections),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.offAll(() => const LoginScreen()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UColors.primary,
                ),
                child: const Text(UTexts.done),
              ),
            ),
            const SizedBox(height: USizes.spaceBtwItems),
            TextButton(
              onPressed: controller.resendPasswordResetEmail,
              child: const Text(UTexts.resendEmail),
            ),
          ],
        ),
      ),
    );
  }
}
