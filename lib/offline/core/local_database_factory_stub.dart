import 'package:sembast/sembast.dart';

Future<Database> openPlatformDatabase(String name) {
  throw UnsupportedError('Offline storage is not supported on this platform.');
}
