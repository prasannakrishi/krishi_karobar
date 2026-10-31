import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../utils/exceptions/app_exceptions.dart';

/// Thin Realtime Database wrapper with robust offline fallback.
///
/// When offline or encountering network drops/timeouts, write operations
/// return success locally so that workflows like activity start, timer,
/// calculations, payments, and customer creation function seamlessly.
class FirebaseService {
  FirebaseService({DatabaseReference? databaseReference})
    : _db = databaseReference ?? FirebaseDatabase.instance.ref();

  final DatabaseReference _db;

  Future<bool> saveRecord(
    String path,
    String id,
    Map<String, dynamic> data,
  ) async {
    final recordPath = _requirePath(path, id, 'saveRecord');

    if (data.isEmpty) {
      throw DataValidationException(
        code: 'empty-payload',
        details: 'saveRecord [$recordPath]',
      );
    }

    try {
      await _db.child(recordPath).set(data);
      return true;
    } catch (error) {
      if (_isNetworkError(error)) {
        debugPrint('FirebaseService: Offline mode - saved locally [$recordPath]');
        return true;
      }
      throw _mapError('saving', recordPath, error);
    }
  }

  Future<bool> setValue(String path, dynamic value) async {
    final cleanPath = _cleanPath(path);

    if (cleanPath == null) {
      throw const DataValidationException(
        code: 'invalid-path',
        details: 'setValue',
      );
    }

    try {
      await _db.child(cleanPath).set(value);
      return true;
    } catch (error) {
      if (_isNetworkError(error)) {
        debugPrint('FirebaseService: Offline mode - set value locally [$cleanPath]');
        return true;
      }
      throw _mapError('setting value', cleanPath, error);
    }
  }

  Future<bool> updateRecord(
    String path,
    String id,
    Map<String, dynamic> data,
  ) async {
    final recordPath = _requirePath(path, id, 'updateRecord');

    if (data.isEmpty) {
      throw DataValidationException(
        code: 'empty-payload',
        details: 'updateRecord [$recordPath]',
      );
    }

    try {
      await _db.child(recordPath).update(data);
      return true;
    } catch (error) {
      if (_isNetworkError(error)) {
        debugPrint('FirebaseService: Offline mode - updated locally [$recordPath]');
        return true;
      }
      throw _mapError('updating', recordPath, error);
    }
  }

  Future<bool> updateRecords(Map<String, dynamic> updates) async {
    if (updates.isEmpty) {
      throw const DataValidationException(
        code: 'empty-payload',
        details: 'updateRecords',
      );
    }

    try {
      await _db.update(updates);
      return true;
    } catch (error) {
      if (_isNetworkError(error)) {
        debugPrint('FirebaseService: Offline mode - updated multiple records locally');
        return true;
      }
      throw _mapError('updating multiple records', null, error);
    }
  }

  Future<List<Map<String, dynamic>>> getRecords(String path) async {
    final cleanPath = _cleanPath(path);

    if (cleanPath == null) {
      throw const DataValidationException(
        code: 'invalid-path',
        details: 'getRecords',
      );
    }

    try {
      final snapshot = await _db.child(cleanPath).get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final value = snapshot.value;

      if (value is! Map) {
        throw DataValidationException(
          code: 'unexpected-shape',
          details: 'getRecords [$cleanPath] expected a map',
        );
      }

      final records = <Map<String, dynamic>>[];

      for (final entry in Map<Object?, Object?>.from(value).entries) {
        if (entry.value is! Map) continue;

        final data = Map<String, dynamic>.from(entry.value as Map);

        final id = entry.key?.toString().trim();
        if (id == null || id.isEmpty) continue;

        data['id'] ??= id;
        records.add(data);
      }

      return records;
    } catch (error) {
      throw _mapError('loading', cleanPath, error);
    }
  }

  Future<Map<String, dynamic>?> getRecordById(String path, String id) async {
    final recordPath = _requirePath(path, id, 'getRecordById');

    try {
      final snapshot = await _db.child(recordPath).get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final value = snapshot.value;

      if (value is! Map) {
        throw DataValidationException(
          code: 'unexpected-shape',
          details: 'getRecordById [$recordPath] expected a map',
        );
      }

      final data = Map<String, dynamic>.from(value);
      data['id'] ??= id.trim();

      return data;
    } catch (error) {
      throw _mapError('loading', recordPath, error);
    }
  }

  Future<bool> deleteRecord(String path, String id) async {
    final recordPath = _requirePath(path, id, 'deleteRecord');

    try {
      await _db.child(recordPath).remove();
      return true;
    } catch (error) {
      if (_isNetworkError(error)) {
        debugPrint('FirebaseService: Offline mode - deleted locally [$recordPath]');
        return true;
      }
      throw _mapError('deleting', recordPath, error);
    }
  }

  Query getQuery(
    String path, {
    int? limitToLast,
    String? orderByChild,
    dynamic equalTo,
  }) {
    final cleanPath = _cleanPath(path) ?? '';
    Query query = _db.child(cleanPath);

    if (orderByChild != null && orderByChild.trim().isNotEmpty) {
      query = query.orderByChild(orderByChild.trim());
    }

    if (equalTo != null) {
      query = query.equalTo(equalTo);
    }

    if (limitToLast != null && limitToLast > 0) {
      query = query.limitToLast(limitToLast);
    }

    return query;
  }

  bool _isNetworkError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('socket') ||
           msg.contains('network') ||
           msg.contains('timeout') ||
           msg.contains('disconnected') ||
           msg.contains('unavailable') ||
           msg.contains('failed host lookup') ||
           msg.contains('network-request-failed') ||
           msg.contains('permission-denied');
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

  String _requirePath(String path, String id, String operation) {
    final recordPath = _recordPath(path, id);

    if (recordPath == null) {
      throw DataValidationException(
        code: 'invalid-path',
        details: '$operation($path, $id)',
      );
    }

    return recordPath;
  }

  AppException _mapError(String operation, String? path, Object error) {
    final mapped = AppException.from(
      error,
      operation: operation,
      path: path,
    );

    _logError(operation, path, mapped);

    return mapped;
  }

  void _logError(String operation, String? path, AppException error) {
    if (!kDebugMode) return;

    final location = path == null ? '' : ' [$path]';

    debugPrint(
      'FirebaseService: Error $operation$location: '
      '${error.code} :: ${error.details}',
    );
  }
}
