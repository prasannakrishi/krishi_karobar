import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:krishi_karobar/firebase_options.dart';
import 'package:krishi_karobar/krishi_karobar_app.dart';
import 'package:krishi_karobar/services/services.dart';
import 'package:krishi_karobar/utils/helper/network_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GetStorage.init();

  Get.put(NetworkManager(), permanent: true);
  Get.put(SequenceService(), permanent: true);
  Get.put(DataCacheService(), permanent: true);

  runApp(const KrishiKarobarApp());
}