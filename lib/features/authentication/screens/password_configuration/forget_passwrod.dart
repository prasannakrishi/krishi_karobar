import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../controllers/forget_password_controller.dart';

class ForgetPassScreen extends StatelessWidget {
  const ForgetPassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ForgetPasswordController());
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(USizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// Heading
              Text(UTexts.forgetPasswordTitle, style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium,),
              const SizedBox(height: USizes.spaceBtwItems,),
              Text(UTexts.forgetPasswordSubTitle, style: Theme
                  .of(context)
                  .textTheme
                  .labelMedium,),
              const SizedBox(height: USizes.spaceBtwSections * 2,),

              /// Text Field
              Form(
                key: controller.forgetPasswordFormKey,
                child: TextFormField(
                  controller: controller.email,
                  decoration: const InputDecoration(
                      labelText: UTexts.email, prefixIcon: Icon(Iconsax.direct_right)),),
              ),
              const SizedBox(height: USizes.spaceBtwSections,),

              /// Submit Button
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => controller.sendPasswordResetOTP(),
                child: const Text(UTexts.submit),),)

            ],
          ),
        ),
      ),
    );
  }
}
