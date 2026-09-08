import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:krishi_karobar/common/widgets/app_scaffold.dart';
import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:krishi_karobar/features/authentication/screens/login/widgets/login_header.dart';
import 'package:krishi_karobar/features/authentication/screens/login/widgets/login_phone_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(LoginController());

    return UAppScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 30),
        child: Column(
            children: const [
              ULoginHeader(),
              ULoginPhoneForm(),
              //ULoginForm()
            ]
        ),
      ),
    );
  }
}
