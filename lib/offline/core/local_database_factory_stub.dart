import 'package:sembast/sembast.dart';

Future<Database> openPlatformDatabase(
  String name, {
  required int version,
  OnVersionChangedFunction? onVersionChanged,
  SembastCodec? codec,
}) {
  throw UnsupportedError('Offline storage is not supported on this platform.');
}
