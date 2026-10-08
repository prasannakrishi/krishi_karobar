import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../../services/firebase_service.dart';
import '../../utils/exceptions/app_exceptions.dart';
import '../offline_models.dart';

enum RemoteCreateResult {
  /// The record did not exist and was written.
  created,

  /// A record with this id already exists. Nothing was written.
  alreadyExists,
}

/// The only place the sync engine talks to Realtime Database. An interface,
/// so the engine and adapters can be tested against a fake.
///
/// Every failure is thrown as an [AppException] (or [TimeoutException]) so
/// the engine can classify it; absence of a record is `null`, not an error.
abstract class SyncRemoteGateway {
  /// True/false as the Firebase connection changes (`.info/connected`).
  Stream<bool> connectionChanges();

  Future<bool> isConnected();

  /// Reads one record from the server. `null` when it does not exist.
  Future<Map<String, Object?>?> readRecord(String path, String id);

  /// Writes [payload] only if nothing exists at `path/id` - atomically.
  /// Never overwrites an existing record.
  Future<RemoteCreateResult> createIfAbsent(
    String path,
    String id,
    Map<String, Object?> payload,
  );

  /// Merges [patch] into `path/id` (existing fields not in [patch] are
  /// kept).
  Future<void> mergeRecord(
    String path,
    String id,
    Map<String, Object?> patch,
  );
}

class FirebaseSyncRemoteGateway implements SyncRemoteGateway {
  FirebaseSyncRemoteGateway({
    FirebaseService? firebaseService,
    DatabaseReference? databaseReference,
    this.timeout = const Duration(seconds: 20),
  })  : _service = firebaseService ?? FirebaseService(),
        _db = databaseReference ?? FirebaseDatabase.instance.ref();

  final FirebaseService _service;
  final DatabaseReference _db;

  /// Transactions wait for the server instead of failing offline, so every
  /// call is bounded; a timeout is reported as a connectivity problem.
  final Duration timeout;

  @override
  Stream<bool> connectionChanges() {
    return _db
        .child('.info/connected')
        .onValue
        .map((event) => event.snapshot.value == true);
  }

  @override
  Future<bool> isConnected() async {
    try {
      final snapshot =
          await _db.child('.info/connected').get().timeout(timeout);
      return snapshot.value == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, Object?>?> readRecord(String path, String id) async {
    final data = await _service.getRecordById(path, id).timeout(timeout);
    return data == null ? null : deepCopyMap(data);
  }

  @override
  Future<RemoteCreateResult> createIfAbsent(
    String path,
    String id,
    Map<String, Object?> payload,
  ) async {
    _requireSegment(path, 'path');
    _requireSegment(id, 'id');

    try {
      final result = await _db.child('$path/$id').runTransaction((current) {
        if (current != null) return Transaction.abort();
        return Transaction.success(deepCopyMap(payload));
      }).timeout(timeout);

      return result.committed
          ? RemoteCreateResult.created
          : RemoteCreateResult.alreadyExists;
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw AppException.from(error);
    }
  }

  @override
  Future<void> mergeRecord(
    String path,
    String id,
    Map<String, Object?> patch,
  ) async {
    await _service.updateRecord(path, id, patch).timeout(timeout);
  }

  void _requireSegment(String value, String name) {
    if (value.trim().isEmpty || value.contains('/')) {
      throw DataValidationException(
        code: 'invalid-path',
        details: 'createIfAbsent $name "$value"',
      );
    }
  }
}
