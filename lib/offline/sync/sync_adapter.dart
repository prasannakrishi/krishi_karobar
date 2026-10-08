import '../core/workspace_scope.dart';
import '../offline_exceptions.dart';
import '../offline_models.dart';
import '../uid/expense_uid_service.dart';

/// How the engine writes a record of this type.
enum SyncWriteMode {
  /// Atomic create-if-absent. An existing id is never overwritten.
  createIfAbsent,

  /// Merge into the existing document (location documents, which the app
  /// already writes with update semantics).
  merge,
}

/// How the engine confirms a write.
enum SyncVerification {
  /// Read the record back and compare it with what was sent.
  readBack,

  /// Reads are not permitted for every role (location documents are
  /// admin-read only), so a successful acknowledged write is the
  /// confirmation.
  writeAcknowledged,
}

/// A record another record depends on (it must exist on the server first).
class SyncParentRef {
  const SyncParentRef(this.entityType, this.recordId);

  final String entityType;
  final String recordId;
}

/// A final uId decided during sync.
class UidResolution {
  const UidResolution({required this.uId, required this.changed});

  final String uId;

  /// True when the value differs from the one currently on the record.
  final bool changed;
}

/// Provisional uId shown for records whose existing generator needs the
/// server. It is NEVER written to Firebase: adapters replace it first and
/// refuse to build a payload while it remains.
class PendingUid {
  PendingUid._();

  static const String prefix = 'PENDING-';

  static String forRecord(String recordId) {
    final compact = recordId.replaceAll('-', '').toUpperCase();
    final short = compact.length > 8 ? compact.substring(0, 8) : compact;
    return '$prefix$short';
  }

  static bool isPending(Object? uId) {
    return uId is String && uId.startsWith(prefix);
  }
}

/// Everything an adapter may need at sync time, injected as plain
/// functions so the existing generators stay untouched and the adapters
/// stay testable.
class SyncAdapterContext {
  const SyncAdapterContext({
    required this.scope,
    required this.reference,
    required this.expenseUid,
    required this.generateSequence,
    required this.generateActivityUid,
  });

  final WorkspaceScope scope;

  /// Reads a record from the reference snapshot (vehicle, service...).
  final Future<Map<String, Object?>?> Function(String type, String id)
      reference;

  final ExpenseUidService expenseUid;

  /// The existing `SequenceService.generateSequence(prefix)`.
  final Future<String> Function(String prefix) generateSequence;

  /// The existing `SequenceService.generateActivityUid(...)`.
  final Future<String> Function({
    required String serviceType,
    required String vehicleUId,
  }) generateActivityUid;
}

/// Describes one entity type to the sync engine: where it lives, what it
/// depends on, how its uId is finalised and what to send.
abstract class SyncAdapter {
  const SyncAdapter();

  String get entityType;

  /// Realtime Database collection, e.g. `expenses`.
  String get remotePath;

  /// Reference-snapshot type the verified server copy moves to after sync;
  /// `null` when nothing should be kept.
  String? get referenceType;

  /// Lower runs first. Parents always have a lower rank than children.
  int get dependencyRank;

  SyncWriteMode get writeMode => SyncWriteMode.createIfAbsent;

  SyncVerification get verification => SyncVerification.readBack;

  /// Fields that must never change after creation.
  List<String> get immutableFields => const ['id', 'createdAt', 'createdBy'];

  /// Records that must exist on the server before this one can be written.
  List<SyncParentRef> parentsOf(LocalRecord record) => const [];

  /// Finalises the uId when the adapter needs to. Returns `null` when the
  /// uId is already final (or [uidClaimed] says it was settled earlier).
  /// The engine stores the result on the record before building a payload.
  Future<UidResolution?> resolveUid(
    SyncAdapterContext context,
    LocalRecord record, {
    required bool uidClaimed,
  }) async {
    return null;
  }

  /// Full payload for a create. Never contains a pending uId.
  Map<String, Object?> buildCreatePayload(LocalRecord record) {
    if (PendingUid.isPending(record.data['uId'])) {
      throw SyncPreparationException.pendingUid(recordId: record.recordId);
    }

    final payload = deepCopyMap(record.data);
    payload['id'] = record.recordId;
    return payload;
  }

  /// Fields sent for an update of an existing server record.
  Map<String, Object?> buildUpdatePatch(LocalRecord record) {
    final patch = deepCopyMap(record.data);
    for (final field in immutableFields) {
      patch.remove(field);
    }
    return patch;
  }
}
