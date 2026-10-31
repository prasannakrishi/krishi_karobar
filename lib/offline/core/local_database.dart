import 'package:sembast/sembast.dart';

import 'local_database_factory.dart';
import 'offline_schema.dart';

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

  /// Opens (and, if needed, migrates) the database. A migration failure
  /// rolls back and is reported as an exception; the file is left as it was.
  ///
  /// [codec] is the encryption extension point: a Sembast codec (for
  /// example AES) can be supplied here once a key-management decision is
  /// made. Phase 0 passes none, so the file stays plain text and nothing is
  /// encrypted or re-written. Encryption at rest is required before
  /// production; adding a codec later means migrating the existing plain
  /// file into a new encrypted one - it cannot be switched on in place.
  static Future<LocalDatabase> open({
    required String environmentName,
    SembastCodec? codec,
  }) async {
    final database = await openPlatformDatabase(
      fileNameFor(environmentName),
      version: OfflineSchema.version,
      onVersionChanged: (db, oldVersion, newVersion) => OfflineSchema.migrate(
        db,
        oldVersion,
        newVersion,
        environment: environmentName,
      ),
      codec: codec,
    );
    return LocalDatabase._(database);
  }

  Future<void> close() => database.close();
}
