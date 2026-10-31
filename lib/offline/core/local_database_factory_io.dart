import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

/// Android / desktop: one file in the app documents directory.
Future<Database> openPlatformDatabase(
  String name, {
  required int version,
  OnVersionChangedFunction? onVersionChanged,
  SembastCodec? codec,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  await directory.create(recursive: true);

  return databaseFactoryIo.openDatabase(
    p.join(directory.path, name),
    version: version,
    onVersionChanged: onVersionChanged,
    codec: codec,
  );
}
