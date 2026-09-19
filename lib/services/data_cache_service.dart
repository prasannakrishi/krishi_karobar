import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/models.dart';
import '../utils/exceptions/app_exceptions.dart';
import 'authorization_service.dart';
import 'firebase_service.dart';

/// Realtime mirror of the business tables the CURRENT session is allowed to
/// hold locally.
///
/// Two levels of scoping apply (spec section 22):
///   1. path level  - `Authz.canCachePath` decides whether a table loads at
///      all (guests load nothing, external users never load payments, ...).
///   2. record level - `_isInScope` keeps only the records the session may
///      see, and evicts a record that later moves out of scope.
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

  @override
  bool get hasListeners => _listeners.isNotEmpty;

  UserModel? get currentUser => _currentUser;

  Future<void> initializeForUser(UserModel user) async {
    if (user.isGuest || !Authz.isSessionValid(actor: user)) {
      await clearCache();
      _currentUser = user;
      return;
    }

    if (_isInitialized && _currentUser?.id == user.id) {
      return;
    }

    if (_initFuture != null) {
      await _initFuture;
      if (_isInitialized && _currentUser?.id == user.id) {
        return;
      }
    }

    _currentUser = user;
    _initFuture = _initialize(user);

    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _initialize(UserModel user) async {
    try {
      await _cancelListeners();
      await _clearData();

      // Vehicles first: the users/activities scope checks read from it.
      await _setupCache<VehicleModel>(
        user: user,
        path: 'vehicles',
        cache: vehicles,
        fromMap: VehicleModel.fromMap,
      );

      await Future.wait([
        _setupCache<UserModel>(
          user: user,
          path: 'users',
          cache: users,
          fromMap: UserModel.fromMap,
        ),
        _setupCache<CustomerModel>(
          user: user,
          path: 'customers',
          cache: customers,
          fromMap: CustomerModel.fromMap,
        ),
        _setupCache<ServiceModel>(
          user: user,
          path: 'services',
          cache: services,
          fromMap: ServiceModel.fromMap,
        ),
        _setupCache<ActivityModel>(
          user: user,
          path: 'activities',
          cache: activities,
          fromMap: ActivityModel.fromMap,
          limitToLast: 50,
        ),
        _setupCache<PaymentModel>(
          user: user,
          path: 'payments',
          cache: payments,
          fromMap: PaymentModel.fromMap,
        ),
      ]);

      _currentUser = user;
      _isInitialized = true;
    } catch (error) {
      _isInitialized = false;
      _currentUser = null;
      _logError('initializing cache', null, error);
      rethrow;
    }
  }

  Future<void> _setupCache<T>({
    required UserModel user,
    required String path,
    required RxMap<String, T> cache,
    required T Function(Map<String, dynamic>) fromMap,
    int? limitToLast,
  }) async {
    if (!Authz.canCachePath(path, actor: user)) return;

    try {
      final query = _firebaseService.getQuery(
        path,
        limitToLast: limitToLast,
      );

      final snapshot = await query.get();

      if (snapshot.exists && snapshot.value is Map) {
        final value = Map<Object?, Object?>.from(snapshot.value as Map);

        for (final entry in value.entries) {
          if (entry.value is! Map) continue;

          final data = Map<String, dynamic>.from(
            entry.value as Map,
          );

          final id = entry.key?.toString().trim();
          if (id == null || id.isEmpty) continue;

          data['id'] ??= id;

          _addToCache(
            path: path,
            cache: cache,
            data: data,
            fromMap: fromMap,
          );
        }
      }

      _listeners.add(
        query.onChildAdded.listen(
              (event) => _handleChildAdded(
            path: path,
            cache: cache,
            snapshot: event.snapshot,
            fromMap: fromMap,
          ),
        ),
      );

      _listeners.add(
        query.onChildChanged.listen(
              (event) => _handleChildChanged(
            path: path,
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

      // The database rules are the final boundary and may be stricter than
      // the client. A refused table degrades that feature only - it must not
      // abort the whole session.
      final mapped = AppException.from(error, operation: 'loading', path: path);

      if (mapped is AuthorizationException) return;

      rethrow;
    }
  }

  void _handleChildAdded<T>({
    required String path,
    required RxMap<String, T> cache,
    required DataSnapshot snapshot,
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    _addToCache(
      path: path,
      cache: cache,
      data: _snapshotToMap(snapshot),
      fromMap: fromMap,
    );
  }

  void _handleChildChanged<T>({
    required String path,
    required RxMap<String, T> cache,
    required DataSnapshot snapshot,
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    _addToCache(
      path: path,
      cache: cache,
      data: _snapshotToMap(snapshot),
      fromMap: fromMap,
    );
  }

  void _handleChildRemoved<T>({
    required RxMap<String, T> cache,
    required DataSnapshot snapshot,
  }) {
    final id = snapshot.key?.trim();

    if (id == null || id.isEmpty) return;

    cache.remove(id);
  }

  void _addToCache<T>({
    required String path,
    required RxMap<String, T> cache,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    final id = data['id']?.toString().trim();

    if (id == null || id.isEmpty) return;

    if (T == UserModel && id == UserModel.systemUser.id) {
      return;
    }

    final T record;

    try {
      record = fromMap(data);
    } catch (error) {
      // A corrupt record is skipped, never stored as a valid-looking empty
      // one (spec section 24).
      _logError(
        'parsing record $id',
        path,
        DataValidationException(
          code: 'model-parse-failed',
          details: '$path/$id :: $error',
        ),
      );
      return;
    }

    if (!_isInScope(path, record)) {
      cache.remove(id);
      return;
    }

    cache[id] = record;
  }

  /// Record-level read scope for the current session.
  bool _isInScope<T>(String path, T record) {
    final user = _currentUser;

    if (user == null) return false;

    if (record is VehicleModel) {
      return Authz.canViewVehicle(record, actor: user);
    }

    if (record is ActivityModel) {
      return Authz.canViewActivity(
        record,
        vehicles[record.vehicleId],
        actor: user,
      );
    }

    if (record is UserModel) {
      if (record.id == user.id) return true;
      if (Authz.can(Permissions.userView, actor: user)) return true;

      // Without user.view a session still needs the names of the people
      // attached to the vehicles it can see.
      return vehicles.values.any(
        (vehicle) =>
            vehicle.ownerId == record.id ||
            vehicle.driverId == record.id ||
            vehicle.supervisorId == record.id,
      );
    }

    return true;
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
    await _clearData();

    _currentUser = null;
    _isInitialized = false;
    _initFuture = null;
  }

  Future<void> _clearData() async {
    users.clear();
    customers.clear();
    vehicles.clear();
    services.clear();
    activities.clear();
    payments.clear();
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
    switch (path.trim().toLowerCase()) {
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
    return getCache<T>(path)[id.trim()];
  }

  T? getRecordByValue<T>(String path,bool Function(T item) test,) {
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
    if (!kDebugMode) return;

    final location = path == null ? '' : ' [$path]';

    debugPrint(
      'DataCacheService: Error $operation$location: '
      '${AppException.from(error)}',
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
