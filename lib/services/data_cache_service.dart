import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/models.dart';

class DataCacheService extends GetxController {
  static DataCacheService get instance => Get.find();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Maps to store data by GUID for fast lookup
  final users = <String, UserModel>{}.obs;
  final customers = <String, CustomerModel>{}.obs;
  final vehicles = <String, VehicleModel>{}.obs;
  final services = <String, ServiceModel>{}.obs;
  final activities = <String, ActivityModel>{}.obs;

  @override
  void onInit() {
    super.onInit();
    // System User is always in cache
    users[UserModel.systemGuid] = UserModel.systemUser;
  }

  /// Initial load of top 50 records and setup real-time listeners
  Future<void> initCache() async {
    await Future.wait([
      _setupListener('users', (data) => UserModel.fromMap(data), users),
      _setupListener('customers', (data) => CustomerModel.fromMap(data), customers),
      _setupListener('vehicles', (data) => VehicleModel.fromMap(data), vehicles),
      _setupListener('services', (data) => ServiceModel.fromMap(data), services),
      _setupListener('activities', (data) => ActivityModel.fromMap(data), activities, limit: 50),
    ]);
  }

  Future<void> _setupListener<T>(
    String path,
    T Function(Map<String, dynamic>) fromMap,
    RxMap<String, T> cache, {
    int? limit,
  }) async {
    Query query = _db.child(path);
    if (limit != null) {
      query = query.limitToLast(limit);
    }

    // 1. Initial Fetch
    final snapshot = await query.get();
    if (snapshot.exists) {
      final rawData = snapshot.value as Map;
      rawData.forEach((key, value) {
        try {
          final data = Map<String, dynamic>.from(value as Map);
          final model = fromMap(data);
          final guid = (data['guid'] ?? key).toString();
          cache[guid] = model;
        } catch (e) {
          debugPrint('Error parsing $path ($key): $e');
        }
      });
    }

    // 2. Listen for Changes
    query.onChildAdded.listen((event) {
      _updateCache(event.snapshot, fromMap, cache);
    });

    query.onChildChanged.listen((event) {
      _updateCache(event.snapshot, fromMap, cache);
    });

    query.onChildRemoved.listen((event) {
      final key = event.snapshot.key;
      if (key != null) {
        // Find by key if guid is not available, but usually we use GUID
        // Realistically we'd need to search the map if key != guid
        cache.remove(key);
      }
    });
  }

  void _updateCache<T>(
    DataSnapshot snapshot,
    T Function(Map<String, dynamic>) fromMap,
    RxMap<String, T> cache,
  ) {
    try {
      if (snapshot.value == null) return;
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final model = fromMap(data);
      final guid = (data['guid'] ?? snapshot.key).toString();
      cache[guid] = model;
    } catch (e) {
      debugPrint('Error updating cache for ${snapshot.key}: $e');
    }
  }

  // --- Lookup Methods ---

  UserModel getUser(String? guid) {
    if (guid == null || guid.isEmpty) return UserModel.empty();
    return users[guid] ?? UserModel.empty();
  }

  CustomerModel getCustomer(String? guid) {
    if (guid == null || guid.isEmpty) return CustomerModel.empty();
    return customers[guid] ?? CustomerModel.empty();
  }

  VehicleModel getVehicle(String? guid) {
    if (guid == null || guid.isEmpty) return VehicleModel.empty();
    return vehicles[guid] ?? VehicleModel.empty();
  }

  ServiceModel getService(String? guid) {
    if (guid == null || guid.isEmpty) return ServiceModel.empty();
    return services[guid] ?? ServiceModel.empty();
  }
  
  String getUserName(String? guid) {
    if (guid == null || guid.isEmpty) return '';
    return users[guid]?.fullname ?? 'Unknown User';
  }

  String getCustomerName(String? guid) {
    if (guid == null || guid.isEmpty) return '';
    return customers[guid]?.name ?? 'Unknown Customer';
  }

  String getVehicleNumber(String? guid) {
    if (guid == null || guid.isEmpty) return '';
    return vehicles[guid]?.number ?? 'Unknown';
  }

  String getServiceName(String? guid) {
    if (guid == null || guid.isEmpty) return '';
    return services[guid]?.name ?? 'Unknown Service';
  }
}
