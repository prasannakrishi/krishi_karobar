import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

class SequenceService extends GetxService {
  static SequenceService get instance => Get.find<SequenceService>();

  SequenceService({DatabaseReference? databaseReference})
      : _db = databaseReference ?? FirebaseDatabase.instance.ref();

  final DatabaseReference _db;

  static const String _sequencePath = 'sequences';
  static const String _activitySequencePath = 'activity_id';

  Future<String> generateSequence(String prefix) async {
    final key = _validatePrefix(prefix);
    final ref = _db.child('$_sequencePath/$key');

    final result = await ref.runTransaction((data) {
      if (data == null) return Transaction.abort();

      final current = data.toString().trim();
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(current);

      if (match == null) return Transaction.abort();

      final text = match.group(1)!;
      final numberText = match.group(2)!;
      final number = int.tryParse(numberText);

      if (number == null) return Transaction.abort();

      final nextNumber =
      (number + 1).toString().padLeft(numberText.length, '0');

      return Transaction.success('$text$nextNumber');
    });

    if (!result.committed || result.snapshot.value == null) {
      throw StateError('Failed to generate sequence for "$key".');
    }

    return result.snapshot.value.toString();
  }

  Future<String> generateActivityUid({
    required String serviceType,
    required String vehicleUId,
  }) async {
    final service = serviceType.trim();
    final vehicle = vehicleUId.trim();

    if (service.isEmpty) {
      throw ArgumentError('Service type cannot be empty.');
    }

    if (vehicle.isEmpty) {
      throw ArgumentError('Vehicle UID cannot be empty.');
    }

    if (!vehicle.toUpperCase().startsWith('V')) {
      throw ArgumentError(
        'Vehicle UID must start with "V": "$vehicle".',
      );
    }

    final vehiclePart = vehicle.substring(1);

    if (vehiclePart.isEmpty) {
      throw ArgumentError('Invalid vehicle UID: "$vehicle".');
    }

    final serviceCode = service[0].toUpperCase();
    final now = DateTime.now();
    final period =
        '${now.year % 10}${now.month.toString().padLeft(2, '0')}';

    final ref =
    _db.child('$_sequencePath/$_activitySequencePath/$period');

    final result = await ref.runTransaction((data) {
      if (data == null) {
        return Transaction.success('$period${'0001'}');
      }

      final current = data.toString().trim();

      if (!current.startsWith(period)) {
        return Transaction.abort();
      }

      final currentNumber =
      int.tryParse(current.substring(period.length));

      if (currentNumber == null) {
        return Transaction.abort();
      }

      final nextNumber = currentNumber + 1;

      return Transaction.success(
        '$period${nextNumber.toString().padLeft(4, '0')}',
      );
    });

    if (!result.committed || result.snapshot.value == null) {
      throw StateError(
        'Failed to generate activity sequence for "$period".',
      );
    }

    final storedValue = result.snapshot.value.toString().trim();

    if (!storedValue.startsWith(period)) {
      throw StateError(
        'Invalid activity sequence value: "$storedValue".',
      );
    }

    final sequenceNumber =
    int.tryParse(storedValue.substring(period.length));

    if (sequenceNumber == null) {
      throw StateError(
        'Invalid activity sequence value: "$storedValue".',
      );
    }

    final sequence = sequenceNumber.toString().padLeft(3, '0');

    return '$serviceCode$vehiclePart-$period$sequence';
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