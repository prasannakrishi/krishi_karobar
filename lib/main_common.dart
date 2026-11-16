import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:krishi_karobar/firebase_options.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:krishi_karobar/services/services.dart';
import 'package:krishi_karobar/utils/constants/environment_config.dart';
import 'package:krishi_karobar/utils/helper/network_manager.dart';

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // RTDB Diagnostic: Independent .info/connected listener and instance inspection
  try {
    final app = Firebase.app();
    final options = app.options;
    debugPrint('[RTDB_DIAGNOSTIC] === FIREBASE DATABASE INSTANCE INSPECTION ===');
    debugPrint('[RTDB_DIAGNOSTIC] App Name: ${app.name}');
    debugPrint('[RTDB_DIAGNOSTIC] Project ID: ${options.projectId}');
    debugPrint('[RTDB_DIAGNOSTIC] Database URL: ${options.databaseURL}');
    debugPrint('[RTDB_DIAGNOSTIC] Environment: ${EnvironmentConfig.currentEnvironment.name}');

    final dbRef = FirebaseDatabase.instanceFor(
      app: app,
      databaseURL: options.databaseURL,
    ).ref();

    debugPrint('[RTDB_DIAGNOSTIC] Registering independent .info/connected listener at ${DateTime.now().toIso8601String()}');
    dbRef.child('.info/connected').onValue.listen(
      (event) {
        debugPrint('[RTDB_DIAGNOSTIC] .info/connected EVENT RECEIVED: value=${event.snapshot.value} (type=${event.snapshot.value?.runtimeType}) at ${DateTime.now().toIso8601String()}');
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('[RTDB_DIAGNOSTIC] .info/connected STREAM ERROR: $error\n$stack');
      },
    );
  } catch (e, stack) {
    debugPrint('[RTDB_DIAGNOSTIC] Failed to setup .info/connected listener: $e\n$stack');
  }

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
