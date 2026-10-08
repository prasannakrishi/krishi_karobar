import 'package:sembast_web/sembast_web.dart';

/// Web: IndexedDB, keyed by database name.
Future<Database> openPlatformDatabase(String name) {
  return databaseFactoryWeb.openDatabase(name, version: 1);
}
