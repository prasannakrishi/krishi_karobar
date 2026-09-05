import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:krishi_karobar/models/activity_model.dart';
import 'package:krishi_karobar/models/customer_model.dart';
import 'package:krishi_karobar/models/service_model.dart';
import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:uuid/uuid.dart';

import '../models/vehicle_model.dart';
import '../models/user_model.dart';
import '../utils/helper/helper_widgets.dart';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final GetStorage localStorage = LoginController.localStorage;

  /// Single method to save or update any supported model.
  /// It automatically detects path and sequence keys based on object type.
  Future<bool> save(dynamic model, {bool isUpdate = false}) async {
    late String path;
    late String guid;
    String? sequenceKey;

    switch (model) {
      case UserModel m:
        path = 'users';
        guid = m.guid;
        sequenceKey = 'user_id';
      case CustomerModel m:
        path = 'customers';
        guid = m.guid;
      case VehicleModel m:
        path = 'vehicles';
        guid = m.guid;
      case ActivityModel m:
        path = 'activities';
        sequenceKey = 'activity_id';
        guid = m.guid;
      case ServiceModel m:
        path = 'services';
        guid = m.guid;
      default:
        return false;
    }

    if (isUpdate) { return await updateRecord(model, path, guid);}

    final data = Map<String, dynamic>.from(model.toMap());
    final success = await addNewRecord(data, path, guid);

    if (success && sequenceKey != null) {
      //await updateSequenceId(sequenceKey, model.uid);
    }

    return success;
  }

  Future<void> initializeSystemUser() async {
    try {
      final snapshot = await _db.child('users').child(UserModel.systemUser.guid).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        UserModel.setSystemUser(UserModel.fromMap(data));
        debugPrint("System User loaded from Firebase.");
      }
    } catch (e) {
      debugPrint("Failed to load System User from Firebase: $e");
    }
  }

  /// Core generic method to add a new record.
  Future<bool> addNewRecord(dynamic object, String path, String guid) async {
    try {

      final data = object is Map<String, dynamic> ? object : object.toMap();
      await _db.child(path).child(guid).set(data);
      return true;
    } catch (ex) {
      return false;
    }
  }
  /// Core generic method to update a record.
  Future<bool> updateRecord(dynamic object, String path, String guid) async {
    try {
      final data = object is Map<String, dynamic> ? object : object.toMap();
      await _db.child(path).child(guid).update(data);
      return true;
    } catch (ex) {
      return false;
    }
  }

  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      final userRecord = await _db.child('users').orderByChild('phone').equalTo(phone).get();
      if (!userRecord.exists) return null;

      final rawMap = Map<String, dynamic>.from(userRecord.value as Map);
      final firstUser = rawMap.values.first;

      final userMap = Map<String, dynamic>.from(firstUser as Map);
      return UserModel.fromMap(userMap);
    } catch (ex) {
      return null;
    }
  }

  Future<UserModel?> getUserById(String id) async {
    try {
      final userRecord = await _db.child('users').child(id).get();
      if (!userRecord.exists) return null;

      final userMap = Map<String, dynamic>.from(userRecord.value as Map);
      return UserModel.fromMap(userMap);
    } catch (ex) {
      return null;
    }
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    try {
      final customerRecord = await _db.child('customers').child(id).get();
      if (!customerRecord.exists) return null;

      final customerMap = Map<String, dynamic>.from(customerRecord.value as Map);
      return CustomerModel.fromMap(customerMap);
    } catch (ex) {
      return null;
    }
  }

  // --- ID Generation Methods ---

  Future<String> generateUserId(String address, String wadaNo) async {
    final addressChar = address.isNotEmpty ? address[0].toUpperCase() : 'X';
    final sequenceRef = _db.child('sequences').child('user_id');
    final snapshot = await sequenceRef.get();
    int nextId = snapshot.exists ? (snapshot.value as int) + 1 : 1;

    await sequenceRef.set(nextId);
    final sequenceString = nextId.toString().padLeft(3, '0');
    return '$addressChar$wadaNo-$sequenceString';
  }
  Future<String> generateCustomerId() async {
    try {
      final sequenceRef = _db.child('sequences/customer_id');
      final snapshot = await sequenceRef.get();
      int nextId = snapshot.exists ? (snapshot.value as int) + 1 : 1;

      final sequenceString = nextId.toString().padLeft(6, '0');
      return 'C-$sequenceString';
    } catch (ex) {
      return 'C-000000';
    }
  }
  Future<String> generateActivityUid(String vehicleNumber,String serviceType) async {
    final vehicleLastNumber = RegExp(r'\d+').allMatches(vehicleNumber).last.group(0)!;

    final now = DateTime.now();
    final ymm = '${(now.year % 10).toString()}''${now.month.toString().padLeft(2, '0')}';

    final sequenceRef = _db.child('sequences/activity_id/$ymm');

    final result = await sequenceRef.runTransaction((data) {
      final current = (data as num?)?.toInt() ?? 0;
      data = current + 1;
      return Transaction.success(data);
    });

    final nextId = (result.snapshot.value as num).toInt();
    final sequence = nextId.toString().padLeft(3, '0');

    final serviceChar = serviceType.trim()[0].toUpperCase();

    return '$serviceChar$vehicleLastNumber-$ymm$sequence';
  }


  Future<void> updateSequenceId(String sequenceType, String uid) async {
    final sequenceRef = _db.child('sequences').child(sequenceType);
    int nextId = int.parse(uid.split('-').last);
    await sequenceRef.set(nextId);
  }

  Future<List<T>> getRecords<T>(String table) async {
    try {
      final records = await _db.child(table).get();
      if (!records.exists || records.value == null) return [];

      final rawMap = Map<dynamic, dynamic>.from(records.value as Map);
      return rawMap.entries.map<T>((entry) {
        final data = Map<String, dynamic>.from(entry.value as Map);

        data.putIfAbsent('guid', () => entry.key.toString());
        final Object model;
        switch (table.toLowerCase()) {
          case 'users':
            model = UserModel.fromMap(data);
            break;

          case 'customers':
            model = CustomerModel.fromMap(data);
            break;

          case 'vehicles':
            model = VehicleModel.fromMap(data);
            break;

          case 'services':
            model = ServiceModel.fromMap(data);
            break;

          case 'activities':
            model = ActivityModel.fromMap(data);
            break;

          default:
            throw UnsupportedError('Unsupported table: $table');
        }

        if (model is! T) {
          throw StateError(
            'Table "$table" returns ${model.runtimeType}, not $T',
          );
        }

        return model as T;
      }).toList();
    } catch (ex) {
      debugPrint('Error loading $table: $ex');
      return [];
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final userRecords = await _db.child('users').get();
      if (!userRecords.exists || userRecords.value == null) return [];

      final rawMap = Map<dynamic, dynamic>.from(userRecords.value as Map);
      return rawMap.entries.map((e) {
        final data = Map<String, dynamic>.from(e.value);
        return UserModel.fromMap(data);
      }).toList();
    } catch (ex) {
      return [];
    }
  }
  Future<List<CustomerModel>> getAllCustomers() async {
    try {
      final customerRecords = await _db.child('customers').get();
      if (!customerRecords.exists || customerRecords.value == null) return [];

      final rawMap = Map<dynamic, dynamic>.from(customerRecords.value as Map);
      return rawMap.entries.map((e) {
        final data = Map<String, dynamic>.from(e.value);
        return CustomerModel.fromMap(data);
      }).toList();
    } catch (ex) {
      return [];
    }
  }
  Future<List<VehicleModel>> getAllVehicles() async {
    try {
      final vehicleRecords = await _db.child('vehicles').get();
      if (vehicleRecords.value == null) return [];
      final rawMap = Map<dynamic, dynamic>.from(vehicleRecords.value as Map);

      return rawMap.entries.map((e) {
        final data = Map<String, dynamic>.from(e.value);
        return VehicleModel.fromMap(data);
      }).toList();
    } catch (ex) {
      return [];
    }
  }
  Future<List<ActivityModel>> getActivities([
    DateTime? startDate,
    DateTime? endDate,
  ]) async {
    try {
      final DatabaseReference ref = _db.child('activities');
      Query query = ref.orderByChild('createdAt');
      if (startDate != null || endDate != null) {
        final effectiveStart = startDate ?? DateTime(2026);

        final effectiveEnd = endDate != null
            ? DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
          999,
        )
            : DateTime.now();

        query = query
            .startAt(effectiveStart.toIso8601String())
            .endAt(effectiveEnd.toIso8601String());
      }
      final snapshot = await query.get();
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }
      final rawMap = Map<dynamic, dynamic>.from(
        snapshot.value as Map,
      );
      return rawMap.entries.map((entry) {
        final data = Map<String, dynamic>.from(
          entry.value as Map,
        );
        return ActivityModel.fromMap(data);
      }).toList();
    } catch (ex, stackTrace) {
      errorSnackBar(
        title: 'Failed to Load Activities',
        message: 'Something went wrong while loading activities.',
      );
      return [];
    }
  }

  Future<List<ServiceModel>> getAllServices() async {
    try {
      final serviceRecords = await _db.child('services').get();
      if (serviceRecords.value == null) return [];
      final rawMap = Map<dynamic, dynamic>.from(serviceRecords.value as Map);

      return rawMap.entries.map((e) {
        final data = Map<String, dynamic>.from(e.value as Map);
        return ServiceModel.fromMap(data);
      }).toList();
    } catch (ex) {
      return [];
    }
  }
}

