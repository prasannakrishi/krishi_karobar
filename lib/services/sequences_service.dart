import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

class SequenceService extends GetxService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  static const String _sequencePath = 'sequences';
  static const String _activitySequence = 'activity_id';

  Future<String> generateSequence(String prefix) async {
    final ref = _db.child('$_sequencePath/$prefix');
    final result = await ref.runTransaction((data) {
      final oldId = data?.toString() ?? '$prefix-0';
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(oldId);
      final text = match?.group(1) ?? '$prefix-';
      final numberText = match?.group(2) ?? '0';
      final number = int.tryParse(numberText) ?? 0;
      final nextNumber = number + 1;
      final nextId =
          '$text${nextNumber.toString().padLeft(numberText.length, '0')}';
      return Transaction.success(nextId);
    });
    if (!result.committed || result.snapshot.value == null) {
      throw StateError('Failed to generate sequence for "$prefix".');
    }
    return result.snapshot.value.toString();
  }

  Future<String> generateActivityUid(String vehicleUId,String serviceType,) async {
    final now = DateTime.now();
    final ymm = '${now.year % 10}${now.month.toString().padLeft(2, '0')}';
    final ref = _db.child('$_sequencePath/$_activitySequence/$ymm');
    final result = await ref.runTransaction((data) {
      final current = data is num ? data.toInt() : 0;
      return Transaction.success(current + 1);
    });
    if (!result.committed || result.snapshot.value == null) {
      throw StateError('Failed to generate activity sequence for "$ymm".');
    }
    final nextId = (result.snapshot.value as num).toInt();
    final sequence = nextId.toString().padLeft(3, '0');
    if (serviceType.trim().isEmpty) {
      throw ArgumentError('Service type cannot be empty.');
    }
    final serviceChar = serviceType.trim()[0].toUpperCase();
    return '$serviceChar$vehicleUId-$ymm$sequence';
  }
}
