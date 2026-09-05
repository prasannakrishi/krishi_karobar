
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '/utils/constants/colors.dart';
import '/utils/constants/sizes.dart';
import '/utils/constants/text_strings.dart';
import '/utils/theme/widget_themes/custom_decoration.dart';
import 'package:krishi_karobar/features/authentication/controllers/forget_password_controller.dart';

class UForgetPasswordForm extends StatelessWidget {
const UForgetPasswordForm({super.key});

@override
Widget build(BuildContext context) {
final controller = Get.find<ForgetPasswordController>();

return Form(
key: controller.forgetPasswordFormKey,
child: Column(
children: [
TextFormField(
controller: controller.phone,
keyboardType: TextInputType.phone,
decoration: CustomDecoration.uInputDecoration(
labelText: UTexts.phoneNo,
prefixIcon: const Icon(Iconsax.call),
prefixText: '+977 ',
),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return 'Phone number is required.';
}

if (value.trim().length != 10) {
return 'Enter a valid phone number.';
}

return null;
},
),
const SizedBox(height: USizes.spaceBtwSections),
SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: controller.sendPasswordResetEmail,
style: ElevatedButton.styleFrom(
backgroundColor: UColors.primary,
),
child: const Text(UTexts.submit),
),
),
],
),
);
}
}