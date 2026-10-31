import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../offline/offline_storage.dart';
import '../offline/core/workspace_scope.dart';
import '../features/authentication/controllers/login_controllers.dart';

class SequenceService extends GetxService {
  static SequenceService get instance => Get.find<SequenceService>();

  SequenceService({DatabaseReference? databaseReference})
      : _db = databaseReference ?? FirebaseDatabase.instance.ref();

  final DatabaseReference _db;
  final GetStorage _storage = GetStorage();

  static const String _sequencePath = 'sequences';

  Future<String> generateSequence(String prefix) async {
    final year = DateTime.now().year % 10;
    final key = _validatePrefix(prefix);

    try {
      final ref = _db.child('$_sequencePath/$key');
      final result = await ref.runTransaction((data) {
        if (data == null) {
          return Transaction.success('$prefix$year-0001');
        }

        final current = data.toString().trim();
        final match = RegExp(r'^(.*-)(\d+)$').firstMatch(current);

        if (match == null) return Transaction.abort();

        final numberText = match.group(2)!;
        final number = int.tryParse(numberText);

        if (number == null) return Transaction.abort();

        final nextNumber =
            (number + 1).toString().padLeft(numberText.length, '0');

        return Transaction.success('$prefix$year-$nextNumber');
      }).timeout(const Duration(seconds: 4));

      if (result.committed && result.snapshot.value != null) {
        return result.snapshot.value.toString();
      }
    } catch (_) {
      debugPrint('SequenceService: Offline fallback for sequence $prefix');
    }

    // Local fallback generator
    final storageKey = 'seq_$key';
    int current = _storage.read<int>(storageKey) ?? 0;
    current++;
    await _storage.write(storageKey, current);
    return '$prefix$year-${current.toString().padLeft(4, '0')}';
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
          final scope = WorkspaceScope.forCurrentEnvironment(ownerUserId: userId, authUid: userId);
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
