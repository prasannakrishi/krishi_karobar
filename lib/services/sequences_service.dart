import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

class SequenceService extends GetxService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  static const String _sequencePath = 'sequences';
  static const String _activitySequence = 'activity_id';

  Future<String> generateSequence(String prefix) async {
    final value = prefix.trim().toUpperCase();

    if (value.isEmpty) {
      throw ArgumentError('Sequence prefix cannot be empty.');
    }

    final ref = _db.child('$_sequencePath/$value');

    final result = await ref.runTransaction((data) {
      if (data == null) return Transaction.abort();

      final oldId = data.toString();
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(oldId);

      if (match == null) return Transaction.abort();

      final text = match.group(1)!;
      final numberText = match.group(2)!;
      final number = int.tryParse(numberText);

      if (number == null) return Transaction.abort();

      final nextId ='$text${(number + 1).toString().padLeft(numberText.length, '0')}';

      return Transaction.success(nextId);
    });

    if (!result.committed || result.snapshot.value == null) {
      throw StateError('Failed to generate sequence for "$value".');
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
