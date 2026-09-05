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
    try {
      await _db.child(path).child(id).set(data);
      return true;
    } catch (error) {
      _logError('saving', path, id, error);
      return false;
    }
  }

  Future<bool> updateRecord(
      String path,
      String id,
      Map<String, dynamic> data,
      ) async {
    try {
      await _db.child(path).child(id).update(data);
      return true;
    } catch (error) {
      _logError('updating', path, id, error);
      return false;
    }
  }

  Future<bool> updateRecords(Map<String, dynamic> updates) async {
    try {
      await _db.update(updates);
      return true;
    } catch (error) {
      debugPrint('FirebaseService: Error updating multiple records: $error');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getRecords(
      String path,
      ) async {
    try {
      final snapshot = await _db.child(path).get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final value = snapshot.value;

      if (value is! Map) {
        return [];
      }

      final rawMap = Map<Object?, Object?>.from(value);

      return rawMap.entries
          .where((entry) => entry.value is Map)
          .map((entry) {
        final data = Map<String, dynamic>.from(
          entry.value as Map,
        );

        data['id'] ??= entry.key.toString();

        return data;
      }).toList();
    } catch (error) {
      _logError('loading', path, null, error);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRecordById(
      String path,
      String id,
      ) async {
    try {
      final snapshot = await _db.child(path).child(id).get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final value = snapshot.value;

      if (value is! Map) {
        return null;
      }

      final data = Map<String, dynamic>.from(value);

      data['id'] ??= id;

      return data;
    } catch (error) {
      _logError('loading', path, id, error);
      return null;
    }
  }

  Future<bool> deleteRecord(
      String path,
      String id,
      ) async {
    try {
      await _db.child(path).child(id).remove();
      return true;
    } catch (error) {
      _logError('deleting', path, id, error);
      return false;
    }
  }

  Query getQuery(
      String path, {
        int? limitToLast,
      }) {
    Query query = _db.child(path);

    if (limitToLast != null) {
      query = query.limitToLast(limitToLast);
    }

    return query;
  }

  void _logError(
      String operation,
      String path,
      String? id,
      Object error,
      ) {
    final recordPath = id == null ? path : '$path/$id';

    debugPrint(
      'FirebaseService: Error $operation $recordPath: $error',
    );
  }
}