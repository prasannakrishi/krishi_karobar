import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/utils/theme/theme.dart';

import 'features/authentication/screens/login/login_screen.dart';

class krishi_karobar_app extends StatelessWidget {

  const krishi_karobar_app({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Krishi Karobar',
      //themeMode: ThemeMode.system,
      theme: UAppTheme.lightTheme,
      //darkTheme: UAppTheme.darkTheme,
      home: LoginScreen(),
    );
  }
}
