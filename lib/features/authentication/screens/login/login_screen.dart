import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:krishi_karobar/features/authentication/screens/login/widgets/login_form.dart';
import 'package:krishi_karobar/utils/constants/colors.dart';
import '../../../../common/styles/spacing_styles.dart';
import '../../../../utils/constants/text_strings.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LoginController());
    return  Scaffold(
        backgroundColor: UColors.primaryBackground,
        body: SingleChildScrollView(
            child: Padding(
                padding: USpacingStyle.paddingWithAppBarHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(UTexts.loginTitle, style:Theme.of(context).textTheme.headlineLarge, selectionColor: Colors.greenAccent, textAlign: TextAlign.center),
                    const SizedBox(height: 50),

                    const ULoginForm(),
                  ]
                )
            )
        )
    );
  }
}
