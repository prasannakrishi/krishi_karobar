import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/common/widgets/app_scaffold.dart';
import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:krishi_karobar/features/authentication/screens/login/widgets/login_form.dart';
import 'package:krishi_karobar/utils/constants/image_strings.dart';
import '../../../../utils/constants/text_strings.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(LoginController());
    return UAppScaffold(
      blur: 0.0, // Minimal blur for visual depth
      overlayOpacity: 0.0,
      body: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 90),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        boxShadow: [
                          BoxShadow(color: Colors.black, blurRadius: 30, spreadRadius: 2)
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: const Image(
                          image: AssetImage(UImages.appLogo),
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // App Title
                    Text(
                      UTexts.loginTitle,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),

                    // Tagline
                    Text(
                      UTexts.loginSubTitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Login Form Card
                    const ULoginForm(),
                  ]
              )
          )
      ),
    );
  }
}

