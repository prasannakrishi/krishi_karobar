import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/models.dart';
import 'firebase_service.dart';

class DataCacheService extends GetxController {
  static DataCacheService get instance => Get.find<DataCacheService>();

  DataCacheService({
    FirebaseService? firebaseService,
  }) : _firebaseService = firebaseService ?? FirebaseService();

  final FirebaseService _firebaseService;

  final users = <String, UserModel>{}.obs;
  final customers = <String, CustomerModel>{}.obs;
  final vehicles = <String, VehicleModel>{}.obs;
  final services = <String, ServiceModel>{}.obs;
  final activities = <String, ActivityModel>{}.obs;
  final payments = <String, PaymentModel>{}.obs;

  final List<StreamSubscription<DatabaseEvent>> _listeners = [];

  Future<void>? _initFuture;
  bool _isInitialized = false;
  UserModel? _currentUser;

  bool get isInitialized => _isInitialized;
  bool get hasListeners => _listeners.isNotEmpty;
  UserModel? get currentUser => _currentUser;

  Future<void> initializeForUser(UserModel user) async {
    if (user.isGuest) {
      await clearCache();
      _currentUser = user;
      return;
    }

    if (_isInitialized && _currentUser?.id == user.id) {
      return;
    }

    _currentUser = user;
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await clearCache();

      await Future.wait([
        _setupCache(
          path: 'users',
          cache: users,
          fromMap: UserModel.fromMap,
        ),
        _setupCache(
          path: 'customers',
          cache: customers,
          fromMap: CustomerModel.fromMap,
        ),
        _setupCache(
          path: 'vehicles',
          cache: vehicles,
          fromMap: VehicleModel.fromMap,
        ),
        _setupCache(
          path: 'services',
          cache: services,
          fromMap: ServiceModel.fromMap,
        ),
        _setupCache(
          path: 'activities',
          cache: activities,
          fromMap: ActivityModel.fromMap,
          limitToLast: 50,
        ),
        _setupCache(
          path: 'payments',
          cache: payments,
          fromMap: PaymentModel.fromMap,
        ),
      ]);

      _isInitialized = true;
    } catch (error) {
      _isInitialized = false;
      _logError('initializing cache', null, error);
      rethrow;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _setupCache<T>({
    required String path,
    required RxMap<String, T> cache,
    required T Function(Map<String, dynamic>) fromMap,
    int? limitToLast,
  }) async {
    try {
      final records = await _firebaseService.getRecords(path);

      for (final data in records) {
        _addToCache(
          cache: cache,
          data: data,
          fromMap: fromMap,
        );
      }

      final query = _firebaseService.getQuery(
        path,
        limitToLast: limitToLast,
      );

      _listeners.add(
        query.onChildAdded.listen(
              (event) => _handleChildAdded(
            cache: cache,
            snapshot: event.snapshot,
            fromMap: fromMap,
          ),
        ),
      );

      _listeners.add(
        query.onChildChanged.listen(
              (event) => _handleChildChanged(
            cache: cache,
            snapshot: event.snapshot,
            fromMap: fromMap,
          ),
        ),
      );

      _listeners.add(
        query.onChildRemoved.listen(
              (event) => _handleChildRemoved(
            cache: cache,
            snapshot: event.snapshot,
          ),
        ),
      );
    } catch (error) {
      _logError('loading', path, error);
      rethrow;
    }
  }

  void _handleChildAdded<T>({
    required RxMap<String, T> cache,
    required DataSnapshot snapshot,
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    _addToCache(
      cache: cache,
      data: _snapshotToMap(snapshot),
      fromMap: fromMap,
    );
  }

  void _handleChildChanged<T>({
    required RxMap<String, T> cache,
    required DataSnapshot snapshot,
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    _addToCache(
      cache: cache,
      data: _snapshotToMap(snapshot),
      fromMap: fromMap,
    );
  }

  void _handleChildRemoved<T>({
    required RxMap<String, T> cache,
    required DataSnapshot snapshot,
  }) {
    final id = snapshot.key;

    if (id == null || id.isEmpty) return;

    cache.remove(id);
  }

  void _addToCache<T>({
    required RxMap<String, T> cache,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    try {
      final id = data['id']?.toString();

      if (id == null || id.isEmpty) return;

      if (T == UserModel && id == UserModel.systemUser.id) {
        return;
      }

      cache[id] = fromMap(data);
    } catch (error) {
      _logError('adding record to cache', null, error);
    }
  }

  Map<String, dynamic> _snapshotToMap(DataSnapshot snapshot) {
    final value = snapshot.value;

    if (value is! Map) return {};

    final data = Map<String, dynamic>.from(value);
    data['id'] ??= snapshot.key;

    return data;
  }

  Future<void> clearCache() async {
    await _cancelListeners();

    users.clear();
    customers.clear();
    vehicles.clear();
    services.clear();
    activities.clear();
    payments.clear();

    _currentUser = null;
    _isInitialized = false;
    _initFuture = null;
  }

  Future<void> _cancelListeners() async {
    if (_listeners.isEmpty) return;

    final listeners = List<StreamSubscription<DatabaseEvent>>.from(
      _listeners,
    );

    _listeners.clear();

    await Future.wait(
      listeners.map((listener) => listener.cancel()),
    );
  }

  RxMap<String, T> getCache<T>(String path) {
    switch (path.toLowerCase()) {
      case 'users':
        return users as RxMap<String, T>;
      case 'customers':
        return customers as RxMap<String, T>;
      case 'vehicles':
        return vehicles as RxMap<String, T>;
      case 'services':
        return services as RxMap<String, T>;
      case 'activities':
        return activities as RxMap<String, T>;
      case 'payments':
        return payments as RxMap<String, T>;
      default:
        throw UnsupportedError('Unsupported cache path: $path');
    }
  }

  List<T> getCachedRecords<T>(String path) {
    return getCache<T>(path).values.toList();
  }

  T? getCachedRecord<T>(String path, String id) {
    return getCache<T>(path)[id];
  }

  T? getRecordByValue<T>(
      String path,
      bool Function(T item) test,
      ) {
    for (final item in getCache<T>(path).values) {
      if (test(item)) return item;
    }

    return null;
  }

  void _logError(
      String operation,
      String? path,
      Object error,
      ) {
    final location = path == null ? '' : ' [$path]';
    debugPrint(
      'DataCacheService: Error $operation$location: $error',
    );
  }

  @override
  void onClose() {
    for (final listener in _listeners) {
      listener.cancel();
    }

    _listeners.clear();

    super.onClose();
  }
}