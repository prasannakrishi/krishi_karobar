import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

/// Web: IndexedDB, keyed by database name.
Future<Database> openPlatformDatabase(
  String name, {
  required int version,
  OnVersionChangedFunction? onVersionChanged,
  SembastCodec? codec,
}) {
  return databaseFactoryWeb.openDatabase(
    name,
    version: version,
    onVersionChanged: onVersionChanged,
    codec: codec,
  );
}
