import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'features/authentication/screens/login/login_screen.dart';
import 'features/authentication/screens/session_gate.dart';
import 'features/navigarion/screen/main_screen.dart';
import 'utils/constants/text_strings.dart';
import 'utils/theme/theme.dart';

class KrishiKarobarApp extends StatelessWidget {
  const KrishiKarobarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: UTexts.appName,
      themeMode: ThemeMode.light,
      theme: UAppTheme.lightTheme,
      darkTheme: UAppTheme.darkTheme,
      home: const SessionGate(),
      getPages: [
        GetPage(
          name: '/MainScreen',
          page: () => const MainScreen(),
        ),
        GetPage(
          name: '/LoginScreen',
          page: () => const LoginScreen(),
        ),
      ],
    );
  }
}
