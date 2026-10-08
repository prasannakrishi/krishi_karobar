import 'dart:async';

import 'package:get/get.dart';
import 'package:sembast/sembast.dart';

import '../../utils/exceptions/app_exceptions.dart';
import '../../utils/helper/nepali_date_time.dart';
import '../../utils/helper/network_manager.dart';
import '../data/local_sequence_dao.dart';
import '../offline_exceptions.dart';
import '../offline_storage.dart';
import 'expense_uid_format.dart';
import 'expense_uid_remote.dart';

/// Outcome of reconciling a provisional Expense uId with the server.
class ExpenseUidReconcileResult {
  const ExpenseUidReconcileResult({
    required this.uId,
    required this.previousUId,
    required this.sequence,
    required this.changed,
  });

  /// The uId the record must carry from now on. Only `uId` changes; the
  /// record `id` is never touched.
  final String uId;
  final String previousUId;
  final int sequence;

  /// True when the provisional number was already taken on the server and
  /// a new one was assigned.
  final bool changed;
}

/// Expense-only uId allocation and conflict handling.
///
/// * Sequence scope = vehicle code + FULL Nepali year (2083 and 2093 both
///   display digit 3 but never share a counter).
/// * Online: the server counter is incremented in a transaction.
/// * Offline: `max(last issued, last known server) + 1` from the local
///   counter. Numbers are never reused, even if the record is deleted.
/// * At sync, [reconcile] claims the provisional number: free -> kept,
///   taken -> next free number, `uId` only.
///
/// This is an internal utility for Expense. It does not change how any
/// other model builds its uId.
class ExpenseUidService {
  ExpenseUidService({
    required LocalSequenceDao sequences,
    required ExpenseUidRemote remote,
    int Function(DateTime)? nepaliYearOf,
    Future<bool> Function()? isOnline,
    this.remoteTimeout = const Duration(seconds: 15),
  })  : _sequences = sequences,
        _remote = remote,
        _nepaliYearOf = nepaliYearOf ?? _defaultNepaliYear,
        _isOnline = isOnline ?? _assumeOnline;

  /// Production wiring: local storage, Firebase counter, device network.
  factory ExpenseUidService.forApp() {
    return ExpenseUidService(
      sequences: OfflineStorage.instance.sequences,
      remote: FirebaseExpenseUidRemote(),
      isOnline: () async {
        if (!Get.isRegistered<NetworkManager>()) return true;
        return NetworkManager.instance.isConnected();
      },
    );
  }

  static const String entityKey = 'expense';

  final LocalSequenceDao _sequences;
  final ExpenseUidRemote _remote;
  final int Function(DateTime) _nepaliYearOf;
  final Future<bool> Function() _isOnline;
  final Duration remoteTimeout;

  static int _defaultNepaliYear(DateTime at) => toNepaliCalendar(at).year;
  static Future<bool> _assumeOnline() async => true;

  /// Nepali year used as the sequence scope for a record created at
  /// [createdAt]. Allocation and reconcile both derive it from the
  /// record's own `createdAt`, so they always agree.
  int nepaliYearFor(DateTime createdAt) => _nepaliYearOf(createdAt);

  /// Chooses the allocation path:
  ///  * offline                         -> local
  ///  * unsynced local numbers exist    -> local (an online number could
  ///    collide with a pending provisional one)
  ///  * online                          -> server counter, falling back to
  ///    local if the server cannot be reached.
  Future<ExpenseUid> allocate({
    required String vehicleCode,
    required DateTime createdAt,
    DatabaseClient? client,
  }) async {
    final code = ExpenseUidFormat.normalizeVehicleCode(vehicleCode);
    final year = nepaliYearFor(createdAt);

    if (!await _isOnline()) {
      return allocateOffline(
        vehicleCode: code,
        createdAt: createdAt,
        client: client,
      );
    }

    final local = await _sequences.peek(
      entityKey,
      code,
      '$year',
      client: client,
    );

    if (local != null &&
        local.lastIssuedSequence > local.lastKnownServerSequence) {
      return allocateOffline(
        vehicleCode: code,
        createdAt: createdAt,
        client: client,
      );
    }

    try {
      return await allocateOnline(vehicleCode: code, createdAt: createdAt);
    } catch (error) {
      if (!_isConnectivityProblem(error)) rethrow;

      return allocateOffline(
        vehicleCode: code,
        createdAt: createdAt,
        client: client,
      );
    }
  }

  /// Provisional uId from the local counter. Pass the surrounding
  /// transaction as [client] to issue the number atomically with other
  /// local writes. Never calls Firebase.
  Future<ExpenseUid> allocateOffline({
    required String vehicleCode,
    required DateTime createdAt,
    DatabaseClient? client,
  }) async {
    final code = ExpenseUidFormat.normalizeVehicleCode(vehicleCode);
    final year = nepaliYearFor(createdAt);

    final sequence = await _sequences.allocateNext(
      entityKey,
      code,
      '$year',
      client: client,
    );

    return ExpenseUidFormat.build(
      vehicleCode: code,
      nepaliYear: year,
      sequence: sequence,
    );
  }

  /// Final uId from the server counter. The local counter learns the
  /// server value so later offline numbers continue after it.
  Future<ExpenseUid> allocateOnline({
    required String vehicleCode,
    required DateTime createdAt,
  }) async {
    final code = ExpenseUidFormat.normalizeVehicleCode(vehicleCode);
    final year = nepaliYearFor(createdAt);

    final sequence = await _remote
        .allocateNext(vehicleCode: code, nepaliYear: year)
        .timeout(remoteTimeout);

    await _sequences.recordServerSequence(entityKey, code, '$year', sequence);

    return ExpenseUidFormat.build(
      vehicleCode: code,
      nepaliYear: year,
      sequence: sequence,
    );
  }

  /// Sync-time check/claim of a provisional uId.
  ///
  /// The caller (sync engine) must skip this when the queue entry is
  /// already marked `uidClaimed`, and set that flag once the result has
  /// been stored on the record. Throws [ExpenseUidException] when the
  /// provisional uId is not a valid Expense uId for this vehicle/year, so
  /// a corrupt value is reported instead of being "fixed" silently.
  Future<ExpenseUidReconcileResult> reconcile({
    required String provisionalUId,
    required String vehicleCode,
    required DateTime createdAt,
  }) async {
    final code = ExpenseUidFormat.normalizeVehicleCode(vehicleCode);
    final year = nepaliYearFor(createdAt);
    final parts = ExpenseUidFormat.tryParse(provisionalUId);

    if (parts == null ||
        parts.vehicleCode != code ||
        parts.yearDigit != year % 10) {
      throw ExpenseUidException.invalid(
        message: 'The Expense uId "$provisionalUId" does not match vehicle '
            '$code and Nepali year $year.',
      );
    }

    final claim = await _remote
        .claim(vehicleCode: code, nepaliYear: year, sequence: parts.sequence)
        .timeout(remoteTimeout);

    await _sequences.recordServerSequence(
      entityKey,
      code,
      '$year',
      claim.sequence,
    );
    await _sequences.recordIssuedAtLeast(
      entityKey,
      code,
      '$year',
      claim.sequence,
    );

    final claimed = ExpenseUidFormat.build(
      vehicleCode: code,
      nepaliYear: year,
      sequence: claim.sequence,
    );

    return ExpenseUidReconcileResult(
      uId: claimed.uId,
      previousUId: provisionalUId.trim(),
      sequence: claim.sequence,
      changed: !claim.kept,
    );
  }

  bool _isConnectivityProblem(Object error) {
    if (error is TimeoutException) return true;
    return AppException.from(error) is NetworkException;
  }
}
