import 'package:firebase_database/firebase_database.dart';

import '../offline_exceptions.dart';

/// Result of claiming a provisional sequence on the server.
class ExpenseSequenceClaim {
  const ExpenseSequenceClaim({required this.sequence, required this.kept});

  /// The sequence now owned by the record.
  final int sequence;

  /// True when the provisional number was free and kept; false when it
  /// was already taken and the next free number was assigned instead.
  final bool kept;
}

/// Server side of the Expense sequence. Kept behind an interface so the
/// allocation/reconcile rules can be unit-tested without Firebase.
abstract class ExpenseUidRemote {
  Future<int> allocateNext({
    required String vehicleCode,
    required int nepaliYear,
  });

  Future<ExpenseSequenceClaim> claim({
    required String vehicleCode,
    required int nepaliYear,
    required int sequence,
  });
}

/// Realtime Database implementation.
///
/// Counter path: `sequences/expense_{vehicleCode}/{nepaliYear}` holding an
/// integer. It sits under the existing `sequences/$sequenceKey/$period`
/// rule, so no rules change is needed. The existing `SequenceService` and
/// its counters are not touched.
class FirebaseExpenseUidRemote implements ExpenseUidRemote {
  FirebaseExpenseUidRemote({DatabaseReference? databaseReference})
      : _db = databaseReference ?? FirebaseDatabase.instance.ref();

  final DatabaseReference _db;

  static const String _root = 'sequences';

  DatabaseReference _counter(String vehicleCode, int nepaliYear) {
    return _db.child('$_root/expense_$vehicleCode/$nepaliYear');
  }

  /// Parses a counter value. `null` means "no counter yet" (valid);
  /// [_invalid] means the stored value is not a whole number.
  static const int _invalid = -1;

  static int? _read(Object? data) {
    if (data == null) return null;
    if (data is int) return data >= 0 ? data : _invalid;
    if (data is num) {
      return data == data.truncate() && data >= 0 ? data.toInt() : _invalid;
    }
    final parsed = int.tryParse(data.toString().trim());
    return parsed != null && parsed >= 0 ? parsed : _invalid;
  }

  @override
  Future<int> allocateNext({
    required String vehicleCode,
    required int nepaliYear,
  }) async {
    final result =
        await _counter(vehicleCode, nepaliYear).runTransaction((data) {
      final current = _read(data);
      if (current == _invalid) return Transaction.abort();
      return Transaction.success((current ?? 0) + 1);
    });

    return _committedValue(result, vehicleCode, nepaliYear);
  }

  /// Transaction: if the counter is below [sequence], raise it to
  /// [sequence] (the provisional number is free - keep it); otherwise take
  /// `counter + 1`. A counter value means "that number is taken", so a
  /// number at or below it can never be handed out again.
  @override
  Future<ExpenseSequenceClaim> claim({
    required String vehicleCode,
    required int nepaliYear,
    required int sequence,
  }) async {
    final result =
        await _counter(vehicleCode, nepaliYear).runTransaction((data) {
      final current = _read(data);
      if (current == _invalid) return Transaction.abort();

      final base = current ?? 0;
      return Transaction.success(base < sequence ? sequence : base + 1);
    });

    final value = _committedValue(result, vehicleCode, nepaliYear);
    return ExpenseSequenceClaim(sequence: value, kept: value == sequence);
  }

  int _committedValue(
    TransactionResult result,
    String vehicleCode,
    int nepaliYear,
  ) {
    if (!result.committed) {
      throw ExpenseUidException.counterUnreadable(
        details: 'expense_$vehicleCode/$nepaliYear was not committed',
      );
    }

    final value = _read(result.snapshot.value);

    if (value == null || value == _invalid || value < 1) {
      throw ExpenseUidException.counterUnreadable(
        details: 'expense_$vehicleCode/$nepaliYear = ${result.snapshot.value}',
      );
    }

    return value;
  }
}
