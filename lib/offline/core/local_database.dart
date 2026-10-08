import 'package:sembast/sembast.dart';

import 'local_database_factory.dart';

/// Owns the Sembast [Database]. One file per environment, so development
/// and production builds can never share an offline workspace.
class LocalDatabase {
  LocalDatabase._(this.database);

  /// Wraps an already opened database (used by tests with the in-memory
  /// factory).
  factory LocalDatabase.fromDatabase(Database database) =>
      LocalDatabase._(database);

  final Database database;

  static String fileNameFor(String environmentName) =>
      'kk_offline_$environmentName.db';

  static Future<LocalDatabase> open({required String environmentName}) async {
    final database =
        await openPlatformDatabase(fileNameFor(environmentName));
    return LocalDatabase._(database);
  }

  Future<void> close() => database.close();
}
