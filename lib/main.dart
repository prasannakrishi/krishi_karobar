import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:krishi_karobar/firebase_options.dart';
import 'package:krishi_karobar/krishi_karobar_app.dart';
import 'package:krishi_karobar/features/activity_monitor/controllers/monitor_controller.dart';
import 'package:krishi_karobar/services/data_cache_service.dart';
import 'package:krishi_karobar/utils/helper/network_manager.dart';

import 'features/activity_monitor/controllers/timer_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GetStorage.init();
  Get.put(NetworkManager(), permanent: true);
  Get.put(DataCacheService(), permanent: true);
  Get.put(MonitorController(), permanent: true);
  Get.put(TimerController(), permanent: true);

  runApp(const KrishiKarobarApp());
}

