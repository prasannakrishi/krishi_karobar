/// Shared vocabulary of the Offline Engine. Plain string constants (same
/// style as `ActivityStatus`) so values persist as readable text in Sembast.
class OfflineStores {
  OfflineStores._();

  static const String workspaceMeta = 'workspace_meta';
  static const String opsRecords = 'ops_records';
  static const String refSnapshot = 'ref_snapshot';
  static const String localSequences = 'local_sequences';
  static const String syncQueue = 'sync_queue';
  static const String syncConflicts = 'sync_conflicts';
}

class WorkspaceState {
  WorkspaceState._();

  /// The owner is signed in and may create/edit offline records.
  static const String active = 'active';

  /// Session ended while unsynced data remained. Records are kept and
  /// synchronized, but nothing new may be created until the owner returns.
  static const String locked = 'locked';
}

/// Entity types the queue can reference. The DAO layer accepts any
/// non-empty entity type, so a `user` adapter can be added later without
/// touching storage.
class SyncEntity {
  SyncEntity._();

  static const String customer = 'customer';
  static const String activity = 'activity';
  static const String expense = 'expense';
  static const String payment = 'payment';
  static const String user = 'user';

  /// GPS location documents written next to an activity / expense.
  static const String activityLocation = 'activity_location';
  static const String expenseLocation = 'expense_location';
}

class SyncOperation {
  SyncOperation._();

  static const String create = 'create';
  static const String update = 'update';
}

class QueueStatus {
  QueueStatus._();

  static const String pending = 'pending';
  static const String syncing = 'syncing';
  static const String failed = 'failed';
  static const String conflict = 'conflict';

  /// Waiting for a parent record (e.g. the customer of an activity).
  static const String blocked = 'blocked';
}

class ConflictType {
  ConflictType._();

  /// The immutable record id already exists on the server with
  /// incompatible data.
  static const String idConflict = 'id_conflict';

  /// The server copy changed after this workspace loaded it.
  static const String dataConflict = 'data_conflict';

  static const String parentMissing = 'parent_missing';

  /// Server-side due differs from the locally recorded `previousDue`.
  static const String paymentDueMismatch = 'payment_due_mismatch';

  static const String uidUnresolvable = 'uid_unresolvable';
}

class ConflictStatus {
  ConflictStatus._();

  static const String open = 'open';
  static const String resolved = 'resolved';
}

class ConflictResolution {
  ConflictResolution._();

  static const String keepLocal = 'keep_local';
  static const String keepServer = 'keep_server';
  static const String merge = 'merge';
}

class SyncErrorCategory {
  SyncErrorCategory._();

  static const String unauthenticated = 'unauthenticated';
  static const String noAccess = 'no_access';
  static const String permission = 'permission';
  static const String recordNotFound = 'record_not_found';
  static const String recordAlreadyExists = 'record_already_exists';
  static const String uidConflict = 'uid_conflict';
  static const String dataConflict = 'data_conflict';
  static const String validation = 'validation';
  static const String network = 'network';
  static const String server = 'server';
  static const String unknown = 'unknown';
}

/// Read-only reference data kept so the UI works offline.
class ReferenceType {
  ReferenceType._();

  static const String vehicle = 'vehicle';
  static const String service = 'service';
  static const String customer = 'customer';
  static const String activity = 'activity';
  static const String expense = 'expense';
  static const String expenseCategory = 'expense_category';
  static const String activityLocation = 'activity_location';
}

class OfflineBackoff {
  OfflineBackoff._();

  static const List<Duration> _steps = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  static const Duration max = Duration(minutes: 30);

  /// Delay before retry number [attempt] (1-based).
  static Duration delayFor(int attempt) {
    if (attempt <= 0) return Duration.zero;
    if (attempt > _steps.length) return max;
    return _steps[attempt - 1];
  }
}

String nowUtcIso() => DateTime.now().toUtc().toIso8601String();
