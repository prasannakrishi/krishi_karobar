import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:krishi_karobar/firebase_options.dart';

import '../offline/offline_storage.dart';
import '../features/authentication/controllers/login_controllers.dart';
import 'data_cache_service.dart';

class SequenceService extends GetxService {
  static SequenceService get instance => Get.find<SequenceService>();

  SequenceService({DatabaseReference? databaseReference})
      : _db = databaseReference ?? _defaultDbRef();

  final DatabaseReference _db;

  static DatabaseReference _defaultDbRef() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: DefaultFirebaseOptions.currentPlatform.databaseURL,
      ).ref();
    } catch (_) {
      return FirebaseDatabase.instance.ref();
    }
  }
  final GetStorage _storage = GetStorage();

  static const String _sequencePath = 'sequences';

  Future<String> generateSequence(String prefix) async {
    final year = DateTime.now().year % 10;
    final key = _validatePrefix(prefix);
    final storageKey = 'seq_$key';

    int maxSequence = _storage.read<int>(storageKey) ?? 0;

    // Scan DataCacheService local cache for highest existing sequence for prefix
    if (Get.isRegistered<DataCacheService>()) {
      final cache = DataCacheService.instance;
      if (prefix == 'C') {
        for (final cust in cache.customers.values) {
          final uId = cust.uId;
          final match = RegExp(r'^.*-(\d+)$').firstMatch(uId);
          if (match != null) {
            final seqNum = int.tryParse(match.group(1)!);
            if (seqNum != null && seqNum > maxSequence) {
              maxSequence = seqNum;
            }
          }
        }
      }
    }

    // Try fast 500ms remote transaction if online, falling back instantly if offline/timeout
    try {
      final ref = _db.child('$_sequencePath/$key');
      final result = await ref.runTransaction((data) {
        if (data == null) {
          final initial = maxSequence + 1;
          return Transaction.success('$prefix$year-${initial.toString().padLeft(4, '0')}');
        }

        final currentStr = data.toString().trim();
        final match = RegExp(r'^(.*-)(\d+)$').firstMatch(currentStr);

        if (match == null) return Transaction.abort();

        final numberText = match.group(2)!;
        final number = int.tryParse(numberText);

        if (number == null) return Transaction.abort();

        final nextNumber = (number > maxSequence ? number + 1 : maxSequence + 1)
            .toString()
            .padLeft(4, '0');

        return Transaction.success('$prefix$year-$nextNumber');
      }).timeout(const Duration(milliseconds: 500));

      if (result.committed && result.snapshot.value != null) {
        final resUid = result.snapshot.value.toString().trim();
        final match = RegExp(r'^.*-(\d+)$').firstMatch(resUid);
        if (match != null) {
          final seqNum = int.tryParse(match.group(1)!);
          if (seqNum != null) {
            await _storage.write(storageKey, seqNum);
          }
        }
        return resUid;
      }
    } catch (_) {
      debugPrint('SequenceService: Fast local sequence fallback for $prefix');
    }

    maxSequence++;
    await _storage.write(storageKey, maxSequence);
    final formattedSeq = maxSequence.toString().padLeft(4, '0');
    final nextUid = '$prefix$year-$formattedSeq';

    debugPrint('[SEQUENCE_GENERATED] key=$key uId=$nextUid sequence=$maxSequence');
    return nextUid;
  }

  Future<String> generateActivityUid({required String serviceType, required String vehicleUId}) async {
    final service = serviceType.trim();
    final vehicle = vehicleUId.trim();

    if (service.isEmpty) {
      throw ArgumentError('Service type cannot be empty.');
    }

    if (vehicle.isEmpty) {
      throw ArgumentError('Vehicle UID cannot be empty.');
    }

    String vehiclePart = 'V01';
    if (vehicle.contains('-')) {
      final parts = vehicle.split('-');
      if (parts.length >= 2 && parts[0].length >= 2) {
        final type = parts[0].substring(1, 2);
        final seq = parts[1];
        vehiclePart = '$type$seq';
      } else {
        vehiclePart = vehicle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      }
    } else {
      final clean = vehicle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      vehiclePart = clean.isNotEmpty ? clean : 'V01';
    }

    final serviceCode = service[0].toUpperCase();
    final now = DateTime.now();
    final period = '${now.year % 10}${now.month.toString().padLeft(2, '0')}';

    debugPrint('[ACTIVITY_UID_LOOKUP] vehicleUId=$vehicleUId period=$period');

    // Vehicle-specific sequence storage key
    final storageKey = 'act_seq_${vehicle}_$period';
    int current = _storage.read<int>(storageKey) ?? 0;

    if (current == 0 && OfflineStorage.isAvailable) {
      try {
        final userId = LoginController.loginUser.id;
        if (userId.isNotEmpty) {
          final scope = OfflineStorage.currentScope();
          final records = await OfflineStorage.instance.localRecords.listRecords(
            scope,
            entityType: 'activities',
            vehicleId: vehicle,
          );
          for (final r in records) {
            final uId = r.data['uId']?.toString() ?? '';
            if (uId.contains(period)) {
              final parts = uId.split('-');
              if (parts.length >= 2) {
                final seqPart = parts.last;
                final seqNum = int.tryParse(seqPart);
                if (seqNum != null && seqNum > current) {
                  current = seqNum;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ACTIVITY_UID_LOOKUP] Sembast scan notice: $e');
      }
    }

    current++;
    debugPrint('[ACTIVITY_UID_INCREMENTED] vehicleUId=$vehicleUId nextSequence=$current');

    await _storage.write(storageKey, current);
    final sequence = current.toString().padLeft(3, '0');
    final generatedUid = '$serviceCode$vehiclePart-$period$sequence';

    debugPrint('[ACTIVITY_UID_LOCAL_PERSISTED] generatedUid=$generatedUid');
    return generatedUid;
  }

  String _validatePrefix(String prefix) {
    final value = prefix.trim().toUpperCase();

    if (value.isEmpty) {
      throw ArgumentError('Sequence prefix cannot be empty.');
    }

    if (!RegExp(r'^[A-Z][A-Z0-9]*$').hasMatch(value)) {
      throw ArgumentError('Invalid sequence prefix: "$value".');
    }

    return value;
  }
}
