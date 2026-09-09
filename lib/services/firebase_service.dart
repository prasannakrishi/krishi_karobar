import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  FirebaseService({
    DatabaseReference? databaseReference,
  }) : _db = databaseReference ?? FirebaseDatabase.instance.ref();

  final DatabaseReference _db;

  Future<bool> saveRecord(
      String path,
      String id,
      Map<String, dynamic> data,
      ) async {
    final recordPath = _recordPath(path, id);
    if (recordPath == null || data.isEmpty) return false;

    try {
      await _db.child(recordPath).set(data);
      return true;
    } catch (error) {
      _logError('saving', recordPath, error);
      return false;
    }
  }

  Future<bool> updateRecord(
      String path,
      String id,
      Map<String, dynamic> data,
      ) async {
    final recordPath = _recordPath(path, id);
    if (recordPath == null || data.isEmpty) return false;

    try {
      await _db.child(recordPath).update(data);
      return true;
    } catch (error) {
      _logError('updating', recordPath, error);
      return false;
    }
  }

  Future<bool> updateRecords(Map<String, dynamic> updates) async {
    if (updates.isEmpty) return false;

    try {
      await _db.update(updates);
      return true;
    } catch (error) {
      _logError('updating multiple records', null, error);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getRecords(
      String path,
      ) async {
    final cleanPath = _cleanPath(path);
    if (cleanPath == null) return [];

    try {
      final snapshot = await _db.child(cleanPath).get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final value = snapshot.value;
      if (value is! Map) return [];

      final records = <Map<String, dynamic>>[];

      for (final entry in Map<Object?, Object?>.from(value).entries) {
        if (entry.value is! Map) continue;

        final data = Map<String, dynamic>.from(
          entry.value as Map,
        );

        final id = entry.key?.toString().trim();
        if (id == null || id.isEmpty) continue;

        data['id'] ??= id;
        records.add(data);
      }

      return records;
    } catch (error) {
      _logError('loading', cleanPath, error);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRecordById(
      String path,
      String id,
      ) async {
    final recordPath = _recordPath(path, id);
    if (recordPath == null) return null;

    try {
      final snapshot = await _db.child(recordPath).get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final value = snapshot.value;
      if (value is! Map) return null;

      final data = Map<String, dynamic>.from(value);
      data['id'] ??= id.trim();

      return data;
    } catch (error) {
      _logError('loading', recordPath, error);
      return null;
    }
  }

  Future<bool> deleteRecord(
      String path,
      String id,
      ) async {
    final recordPath = _recordPath(path, id);
    if (recordPath == null) return false;

    try {
      await _db.child(recordPath).remove();
      return true;
    } catch (error) {
      _logError('deleting', recordPath, error);
      return false;
    }
  }

  Query getQuery(
      String path, {
        int? limitToLast,
      }) {
    final cleanPath = _cleanPath(path) ?? '';
    Query query = _db.child(cleanPath);

    if (limitToLast != null && limitToLast > 0) {
      query = query.limitToLast(limitToLast);
    }

    return query;
  }

  String? _cleanPath(String path) {
    final value = path.trim();

    if (value.isEmpty) return null;

    return value.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  String? _recordPath(String path, String id) {
    final cleanPath = _cleanPath(path);
    final cleanId = id.trim();

    if (cleanPath == null || cleanId.isEmpty) {
      return null;
    }

    return '$cleanPath/$cleanId';
  }

  void _logError(
      String operation,
      String? path,
      Object error,
      ) {
    final location = path == null ? '' : ' [$path]';

    debugPrint(
      'FirebaseService: Error $operation$location: $error',
    );
  }
}