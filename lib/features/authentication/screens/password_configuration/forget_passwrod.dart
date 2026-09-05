import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/widgets/app_scaffold.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../controllers/forget_password_controller.dart';
import 'widgets/forget_password_form.dart';

class ForgetPassScreen extends StatelessWidget {
  const ForgetPassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(ForgetPasswordController());

    return UAppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: UColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          USizes.defaultSpace,
          30,
          USizes.defaultSpace,
          USizes.defaultSpace,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              UTexts.forgetPasswordTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: UColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: USizes.spaceBtwItems),
            Text(
              UTexts.forgetPasswordSubTitle,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: USizes.spaceBtwSections * 2),
            const UForgetPasswordForm(),
          ],
        ),
      ),
    );
  }
}
