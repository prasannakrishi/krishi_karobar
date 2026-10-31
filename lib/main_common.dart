import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:krishi_karobar/firebase_options.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:krishi_karobar/services/services.dart';
import 'package:krishi_karobar/utils/helper/network_manager.dart';

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GetStorage.init();

  // A failed local database must be visible, not a debug notice. The app
  // still starts (on its existing online path) and the local file is left
  // untouched; OfflineStorage.initializationError carries the reason.
  try {
    await OfflineStorage.initialize();
  } catch (error, stack) {
    OfflineStorage.reportInitializationFailure(error, stack);
  }

  Get.put(NetworkManager(), permanent: true);
  Get.put(SessionService(), permanent: true);
  Get.put(SequenceService(), permanent: true);
  Get.put(DataCacheService(), permanent: true);
}
