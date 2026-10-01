// File generated and customized for Dev/Prod environments.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'utils/constants/environment_config.dart';

/// Default [FirebaseOptions] that automatically switches between Dev and Prod
/// based on [EnvironmentConfig.isDev].
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return EnvironmentConfig.isDev ? devWeb : prodWeb;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return EnvironmentConfig.isDev ? devAndroid : prodAndroid;
      case TargetPlatform.iOS:
        return EnvironmentConfig.isDev ? devIos : prodIos;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return EnvironmentConfig.isDev ? devWindows : prodWindows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ==================== DEV ENVIRONMENT (krishi-karobar-dev) ====================
  static const FirebaseOptions devAndroid = FirebaseOptions(
    apiKey: 'AIzaSyCE1VW1AVoxg10sllgNbiy-ih4NqxjZLFA',
    appId: '1:224694173482:android:0e50fbae6ac26e77baa853',
    messagingSenderId: '224694173482',
    projectId: 'krishi-karobar-dev',
    databaseURL: 'https://krishi-karobar-dev-default-rtdb.firebaseio.com',
    storageBucket: 'krishi-karobar-dev.firebasestorage.app',
  );

  static const FirebaseOptions devWeb = FirebaseOptions(
    apiKey: 'AIzaSyCE1VW1AVoxg10sllgNbiy-ih4NqxjZLFA',
    appId: '1:224694173482:web:dev_app_id_placeholder',
    messagingSenderId: '224694173482',
    projectId: 'krishi-karobar-dev',
    authDomain: 'krishi-karobar-dev.firebaseapp.com',
    databaseURL: 'https://krishi-karobar-dev-default-rtdb.firebaseio.com',
    storageBucket: 'krishi-karobar-dev.firebasestorage.app',
  );

  static const FirebaseOptions devIos = FirebaseOptions(
    apiKey: 'AIzaSyCE1VW1AVoxg10sllgNbiy-ih4NqxjZLFA',
    appId: '1:224694173482:ios:dev_app_id_placeholder',
    messagingSenderId: '224694173482',
    projectId: 'krishi-karobar-dev',
    databaseURL: 'https://krishi-karobar-dev-default-rtdb.firebaseio.com',
    storageBucket: 'krishi-karobar-dev.firebasestorage.app',
    iosBundleId: 'com.example.krishiKarobarDev',
  );

  static const FirebaseOptions devWindows = FirebaseOptions(
    apiKey: 'AIzaSyCE1VW1AVoxg10sllgNbiy-ih4NqxjZLFA',
    appId: '1:224694173482:web:dev_app_id_placeholder',
    messagingSenderId: '224694173482',
    projectId: 'krishi-karobar-dev',
    authDomain: 'krishi-karobar-dev.firebaseapp.com',
    databaseURL: 'https://krishi-karobar-dev-default-rtdb.firebaseio.com',
    storageBucket: 'krishi-karobar-dev.firebasestorage.app',
  );

  // ==================== PROD ENVIRONMENT (krishi-karobar-8a470) ====================
  static const FirebaseOptions prodAndroid = FirebaseOptions(
    apiKey: 'AIzaSyBsXsxKQiop5f80godBCxOqc4KV7o87M3Y',
    appId: '1:1062624758266:android:353fc5f3fa20f32b037c43',
    messagingSenderId: '1062624758266',
    projectId: 'krishi-karobar-8a470',
    databaseURL: 'https://krishi-karobar-8a470-default-rtdb.firebaseio.com',
    storageBucket: 'krishi-karobar-8a470.firebasestorage.app',
  );

  static const FirebaseOptions prodWeb = FirebaseOptions(
    apiKey: 'AIzaSyC1nX1VJw5X-rKlHR_d91uq1zH8ozKgOOM',
    appId: '1:1062624758266:web:f7734bb4455eb249037c43',
    messagingSenderId: '1062624758266',
    projectId: 'krishi-karobar-8a470',
    authDomain: 'krishi-karobar-8a470.firebaseapp.com',
    databaseURL: 'https://krishi-karobar-8a470-default-rtdb.firebaseio.com',
    storageBucket: 'krishi-karobar-8a470.firebasestorage.app',
    measurementId: 'G-2DBXPKFKDJ',
  );

  static const FirebaseOptions prodIos = FirebaseOptions(
    apiKey: 'AIzaSyDo4iZXNAZWsKYgdewcxQeLV61ZDeeX1ak',
    appId: '1:1062624758266:ios:7352ca57e1cb7961037c43',
    messagingSenderId: '1062624758266',
    projectId: 'krishi-karobar-8a470',
    databaseURL: 'https://krishi-karobar-8a470-default-rtdb.firebaseio.com',
    storageBucket: 'krishi-karobar-8a470.firebasestorage.app',
    iosBundleId: 'com.example.krishiKarobar',
  );

  static const FirebaseOptions prodWindows = FirebaseOptions(
    apiKey: 'AIzaSyC1nX1VJw5X-rKlHR_d91uq1zH8ozKgOOM',
    appId: '1:1062624758266:web:20801dbeb190f44f037c43',
    messagingSenderId: '1062624758266',
    projectId: 'krishi-karobar-8a470',
    authDomain: 'krishi-karobar-8a470.firebaseapp.com',
    databaseURL: 'https://krishi-karobar-8a470-default-rtdb.firebaseio.com',
    storageBucket: 'krishi-karobar-8a470.firebasestorage.app',
    measurementId: 'G-8RKL6T4CC9',
  );
}
