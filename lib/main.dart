import 'package:flutter/material.dart';
import 'package:krishi_karobar/krishi_karobar_app.dart';
import 'package:krishi_karobar/utils/constants/environment_config.dart';
import 'main_common.dart';

Future<void> main() async {
  EnvironmentConfig.setEnvironment(Environment.dev);
  //EnvironmentConfig.setEnvironment(Environment.prod);
  await initializeApp();
  runApp(const KrishiKarobarApp());
}
