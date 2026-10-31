import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/models.dart';
import '../offline/offline_storage.dart';
import '../offline/core/workspace_scope.dart';
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
  final expenses = <String, ExpenseModel>{}.obs;
  final expenseCategories = <String, ExpenseCategoryModel>{}.obs;
  final Map<String, Map<String, dynamic>> _activityLocations = {};

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

      // 1. Load local snapshots and ops first for instant offline startup
      await _loadLocalSnapshotsAndOps(user);

      // 2. Attach real-time Firebase listeners asynchronously in background
      _setupCache<VehicleModel>(
        user: user,
        path: 'vehicles',
        cache: vehicles,
        fromMap: VehicleModel.fromMap,
      );
      _setupCache<UserModel>(
        user: user,
        path: 'users',
        cache: users,
        fromMap: UserModel.fromMap,
      );
      _setupCache<CustomerModel>(
        user: user,
        path: 'customers',
        cache: customers,
        fromMap: CustomerModel.fromMap,
      );
      _setupCache<ServiceModel>(
        user: user,
        path: 'services',
        cache: services,
        fromMap: ServiceModel.fromMap,
      );
      _setupCache<ActivityModel>(
        user: user,
        path: 'activities',
        cache: activities,
        fromMap: ActivityModel.fromMap,
        limitToLast: 50,
      );
      _setupCache<PaymentModel>(
        user: user,
        path: 'payments',
        cache: payments,
        fromMap: PaymentModel.fromMap,
      );
      _setupCache<ExpenseModel>(
        user: user,
        path: 'expenses',
        cache: expenses,
        fromMap: ExpenseModel.fromMap,
        limitToLast: 100,
      );
      _setupCache<ExpenseCategoryModel>(
        user: user,
        path: 'expensecategories',
        cache: expenseCategories,
        fromMap: ExpenseCategoryModel.fromMap,
      );

      if (Authz.canCachePath('activity_locations', actor: user)) {
        _setupActivityLocationsCache();
      }

      _currentUser = user;
      _isInitialized = true;

      try {
        if (OfflineStorage.isAvailable && user.id.isNotEmpty) {
          final authUid = FirebaseAuth.instance.currentUser?.uid ?? user.id;
          final scope = WorkspaceScope.forCurrentEnvironment(
            ownerUserId: user.id,
            authUid: authUid,
          );
          await OfflineStorage.instance.activateWorkspace(
            scope,
            ownerPhone: user.phone,
          );
          debugPrint('[SYNC_ENGINE_STARTED] Workspace activated successfully for user=${user.id}');
        }
      } catch (e) {
        debugPrint('DataCacheService activateWorkspace notice: $e');
      }
    } catch (error) {
      _isInitialized = false;
      _currentUser = null;
      _logError('initializing cache', null, error);
      rethrow;
    }
  }

  Future<void> _loadLocalSnapshotsAndOps(UserModel user) async {
    try {
      if (!OfflineStorage.isAvailable || user.id.isEmpty) return;

      // 1. Load cached reference snapshots from local DB (Sembast). They
      // live in the owner's global namespace (see OfflineStorage).
      final ns = OfflineStorage.snapshotNamespace(user.id);
      try {
        final localVehicles = await OfflineStorage.instance.snapshots.list(ns, 'vehicles');
        for (final data in localVehicles) {
          try {
            final v = VehicleModel.fromMap(data);
            if (Authz.canViewVehicle(v, actor: user)) {
              vehicles[v.id] = v;
            }
          } catch (e) {
            debugPrint('DataCacheService parse local vehicle error: $e');
          }
        }

        final localUsers = await OfflineStorage.instance.snapshots.list(ns, 'users');
        for (final data in localUsers) {
          try {
            final u = UserModel.fromMap(data);
            users[u.id] = u;
          } catch (_) {}
        }

        final localServices = await OfflineStorage.instance.snapshots.list(ns, 'services');
        for (final data in localServices) {
          try {
            final s = ServiceModel.fromMap(data);
            services[s.id] = s;
          } catch (_) {}
        }

        final localCustomers = await OfflineStorage.instance.snapshots.list(ns, 'customers');
        for (final data in localCustomers) {
          try {
            final c = CustomerModel.fromMap(data);
            customers[c.id] = c;
          } catch (_) {}
        }

        final localActivities = await OfflineStorage.instance.snapshots.list(ns, 'activities');
        for (final data in localActivities) {
          try {
            final a = ActivityModel.fromMap(data);
            activities[a.id] = a;
          } catch (_) {}
        }

        final localPayments = await OfflineStorage.instance.snapshots.list(ns, 'payments');
        for (final data in localPayments) {
          try {
            final p = PaymentModel.fromMap(data);
            payments[p.id] = p;
          } catch (_) {}
        }

        final localExpenses = await OfflineStorage.instance.snapshots.list(ns, 'expenses');
        for (final data in localExpenses) {
          try {
            final e = ExpenseModel.fromMap(data);
            expenses[e.id] = e;
          } catch (_) {}
        }

        final localCategories = await OfflineStorage.instance.snapshots.list(ns, 'expensecategories');
        for (final data in localCategories) {
          try {
            final cat = ExpenseCategoryModel.fromMap(data);
            expenseCategories[cat.id] = cat;
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('DataCacheService local snapshot load notice: $e');
      }

      // 2. Load pending ops records on top of snapshots
      try {
        final localRecords =
            await OfflineStorage.instance.localRecords.dao.listAllForOwner(user.id, includeDeleted: false);

        for (final record in localRecords) {
          final data = Map<String, dynamic>.from(record.data);
          final type = record.entityType;

          if (type == 'activities' || type == 'activity') {
            try {
              final act = ActivityModel.fromMap(data);
              activities[act.id] = act;
            } catch (e) {
              debugPrint('DataCacheService parse activity error: $e');
            }
          } else if (type == 'expenses' || type == 'expense') {
            try {
              final exp = ExpenseModel.fromMap(data);
              expenses[exp.id] = exp;
            } catch (e) {
              debugPrint('DataCacheService parse expense error: $e');
            }
          } else if (type == 'customers' || type == 'customer') {
            try {
              final cust = CustomerModel.fromMap(data);
              customers[cust.id] = cust;
            } catch (e) {
              debugPrint('DataCacheService parse customer error: $e');
            }
          } else if (type == 'payments' || type == 'payment') {
            try {
              final pay = PaymentModel.fromMap(data);
              payments[pay.id] = pay;
            } catch (e) {
              debugPrint('DataCacheService parse payment error: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('DataCacheService local record load notice: $e');
      }

      vehicles.refresh();
      users.refresh();
      services.refresh();
      activities.refresh();
      expenses.refresh();
      customers.refresh();
      payments.refresh();
      expenseCategories.refresh();
    } catch (e) {
      debugPrint('DataCacheService _loadLocalSnapshotsAndOps notice: $e');
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

      _listeners.add(
        query.onChildAdded.listen(
          (event) => _handleChildAdded(
            path: path,
            cache: cache,
            snapshot: event.snapshot,
            fromMap: fromMap,
          ),
          onError: (e) => debugPrint('DataCacheService $path onChildAdded notice: $e'),
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
          onError: (e) => debugPrint('DataCacheService $path onChildChanged notice: $e'),
        ),
      );

      _listeners.add(
        query.onChildRemoved.listen(
          (event) => _handleChildRemoved(
            cache: cache,
            snapshot: event.snapshot,
          ),
          onError: (e) => debugPrint('DataCacheService $path onChildRemoved notice: $e'),
        ),
      );
    } catch (e) {
      debugPrint('DataCacheService _setupCache notice for $path: $e');
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

    if (record is ActivityModel && _activityLocations.containsKey(id)) {
      final locs = _activityLocations[id]!;
      if (locs['startLocation'] != null && locs['startLocation'] is Map) {
        record.startLocation = ActivityLocationModel.fromMap(
          Map<String, dynamic>.from(locs['startLocation'] as Map),
        );
      }
      if (locs['stopLocation'] != null && locs['stopLocation'] is Map) {
        record.stopLocation = ActivityLocationModel.fromMap(
          Map<String, dynamic>.from(locs['stopLocation'] as Map),
        );
      }
    }

    cache[id] = record;

    final user = _currentUser;
    if (OfflineStorage.isAvailable && user != null && user.id.isNotEmpty) {
      try {
        OfflineStorage.instance.snapshots.put(
          workspaceId: OfflineStorage.snapshotNamespace(user.id),
          type: path,
          recordId: id,
          data: data,
        );
      } catch (e) {
        debugPrint('DataCacheService snapshot save notice: $e');
      }
    }
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
    _activityLocations.clear();
  }

  Future<void> _setupActivityLocationsCache() async {
    try {
      final query = _firebaseService.getQuery(
        'activity_locations',
        limitToLast: 50,
      );
      final snapshot = await query.get().timeout(const Duration(seconds: 2));
      if (snapshot.exists && snapshot.value is Map) {
        final value = Map<Object?, Object?>.from(snapshot.value as Map);
        for (final entry in value.entries) {
          if (entry.value is! Map) continue;
          final id = entry.key?.toString().trim();
          if (id == null || id.isEmpty) continue;
          final data = Map<String, dynamic>.from(entry.value as Map);
          _activityLocations[id] = data;
          _mergeLocationToActivity(id, data);
        }
      }

      _listeners.add(
        query.onChildAdded.listen((event) {
          final id = event.snapshot.key?.trim();
          if (id == null || id.isEmpty || event.snapshot.value is! Map) return;
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          _activityLocations[id] = data;
          _mergeLocationToActivity(id, data);
        }),
      );

      _listeners.add(
        query.onChildChanged.listen((event) {
          final id = event.snapshot.key?.trim();
          if (id == null || id.isEmpty || event.snapshot.value is! Map) return;
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          _activityLocations[id] = data;
          _mergeLocationToActivity(id, data);
        }),
      );
    } catch (error) {
      _logError('loading', 'activity_locations', error);
    }
  }

  void _mergeLocationToActivity(String id, Map<String, dynamic> data) {
    final activity = activities[id];
    if (activity != null) {
      if (data['startLocation'] != null && data['startLocation'] is Map) {
        activity.startLocation = ActivityLocationModel.fromMap(
          Map<String, dynamic>.from(data['startLocation'] as Map),
        );
      }
      if (data['stopLocation'] != null && data['stopLocation'] is Map) {
        activity.stopLocation = ActivityLocationModel.fromMap(
          Map<String, dynamic>.from(data['stopLocation'] as Map),
        );
      }
      activities[id] = activity;
      activities.refresh();
    }
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
