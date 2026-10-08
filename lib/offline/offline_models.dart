import 'core/workspace_scope.dart';
import 'offline_constants.dart';

/// Detached deep copy of a stored map. Sembast hands out immutable maps;
/// every model copies on the way in and out so callers never mutate (or
/// alias) stored data.
Map<String, Object?> deepCopyMap(Map<dynamic, dynamic> source) {
  return {
    for (final entry in source.entries)
      entry.key.toString(): _deepCopy(entry.value),
  };
}

Object? _deepCopy(Object? value) {
  if (value is Map) return deepCopyMap(value);
  if (value is List) return value.map(_deepCopy).toList();
  return value;
}

DateTime _time(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _timeOrNull(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

String _iso(DateTime value) => value.toUtc().toIso8601String();

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _string(Object? value) => value?.toString() ?? '';

// ---------------------------------------------------------------------------
// Workspace
// ---------------------------------------------------------------------------

class WorkspaceInfo {
  const WorkspaceInfo({
    required this.workspaceId,
    required this.environment,
    required this.ownerUserId,
    required this.authUid,
    required this.ownerPhone,
    required this.vehicleId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkspaceInfo.fromMap(Map<String, Object?> map) {
    return WorkspaceInfo(
      workspaceId: _string(map['workspaceId']),
      environment: _string(map['environment']),
      ownerUserId: _string(map['ownerUserId']),
      authUid: _string(map['authUid']),
      ownerPhone: _string(map['ownerPhone']),
      vehicleId: _string(map['vehicleId']),
      state: _string(map['state']),
      createdAt: _time(map['createdAt']),
      updatedAt: _time(map['updatedAt']),
    );
  }

  final String workspaceId;
  final String environment;
  final String ownerUserId;
  final String authUid;

  /// Normalized phone of the owner; lets the login guard compare a
  /// *typed* phone number with the owner before any Firebase sign-in.
  final String ownerPhone;
  final String vehicleId;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLocked => state == WorkspaceState.locked;

  WorkspaceScope get scope => WorkspaceScope(
        environment: environment,
        ownerUserId: ownerUserId,
        authUid: authUid,
        vehicleId: vehicleId,
      );

  WorkspaceInfo copyWith({
    String? authUid,
    String? ownerPhone,
    String? state,
    DateTime? updatedAt,
  }) {
    return WorkspaceInfo(
      workspaceId: workspaceId,
      environment: environment,
      ownerUserId: ownerUserId,
      authUid: authUid ?? this.authUid,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      vehicleId: vehicleId,
      state: state ?? this.state,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'workspaceId': workspaceId,
        'environment': environment,
        'ownerUserId': ownerUserId,
        'authUid': authUid,
        'ownerPhone': ownerPhone,
        'vehicleId': vehicleId,
        'state': state,
        'createdAt': _iso(createdAt),
        'updatedAt': _iso(updatedAt),
      };
}

/// Sync health of a workspace. The workspace may only be cleared when
/// [isClean] - pending, failed, conflicts and orphan records all zero.
class WorkspaceCounts {
  const WorkspaceCounts({
    this.pending = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.orphanRecords = 0,
  });

  /// pending + syncing + blocked queue entries.
  final int pending;
  final int failed;
  final int conflicts;

  /// Local records that have no queue entry. This must never happen; if it
  /// does, the data is kept and reported rather than cleared.
  final int orphanRecords;

  int get unsynced => pending + failed + conflicts + orphanRecords;
  bool get isClean => unsynced == 0;

  @override
  String toString() =>
      'WorkspaceCounts(pending: $pending, failed: $failed, '
      'conflicts: $conflicts, orphans: $orphanRecords)';
}

// ---------------------------------------------------------------------------
// Local operational record (the only copy of pending business data)
// ---------------------------------------------------------------------------

class LocalRecord {
  const LocalRecord({
    required this.workspaceId,
    required this.entityType,
    required this.recordId,
    required this.data,
    required this.isNew,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.baseUpdatedAt,
  });

  factory LocalRecord.fromMap(Map<String, Object?> map) {
    final rawData = map['data'];

    return LocalRecord(
      workspaceId: _string(map['workspaceId']),
      entityType: _string(map['entityType']),
      recordId: _string(map['recordId']),
      data: rawData is Map ? deepCopyMap(rawData) : <String, Object?>{},
      isNew: map['isNew'] == true,
      revision: _int(map['revision']),
      baseUpdatedAt: map['baseUpdatedAt']?.toString(),
      createdAt: _time(map['createdAt']),
      updatedAt: _time(map['updatedAt']),
    );
  }

  final String workspaceId;
  final String entityType;
  final String recordId;

  /// The business record exactly as `Model.toMap()` produced it.
  final Map<String, Object?> data;

  /// True when the record has never reached Firebase.
  final bool isNew;

  /// Increments on every user save. The engine remembers the revision it
  /// synced; a different revision afterwards means the user edited the
  /// record mid-sync and it must not be discarded.
  final int revision;

  /// Server `updatedAt` this record was loaded with (updates only); used
  /// to detect that the server copy changed in the meantime.
  final String? baseUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String keyOf(String entityType, String recordId) =>
      '$entityType|$recordId';

  String get key => keyOf(entityType, recordId);

  LocalRecord copyWith({
    Map<String, Object?>? data,
    bool? isNew,
    int? revision,
    String? baseUpdatedAt,
    bool clearBaseUpdatedAt = false,
    DateTime? updatedAt,
  }) {
    return LocalRecord(
      workspaceId: workspaceId,
      entityType: entityType,
      recordId: recordId,
      data: data ?? this.data,
      isNew: isNew ?? this.isNew,
      revision: revision ?? this.revision,
      baseUpdatedAt:
          clearBaseUpdatedAt ? null : (baseUpdatedAt ?? this.baseUpdatedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'workspaceId': workspaceId,
        'entityType': entityType,
        'recordId': recordId,
        'data': deepCopyMap(data),
        'isNew': isNew,
        'revision': revision,
        'baseUpdatedAt': baseUpdatedAt,
        'createdAt': _iso(createdAt),
        'updatedAt': _iso(updatedAt),
      };
}

enum SyncCompletion {
  /// Verified, moved to the reference snapshot, queue entry removed.
  removed,

  /// The user edited the record while it was syncing. It stays local and
  /// is re-queued as an update on top of the now-existing server record.
  changedDuringSync,
}

// ---------------------------------------------------------------------------
// Sync queue entry - a reference to a local record, never a copy
// ---------------------------------------------------------------------------

class SyncQueueEntry {
  const SyncQueueEntry({
    required this.workspaceId,
    required this.entityType,
    required this.recordId,
    required this.operation,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    this.lastAttemptAt,
    this.nextAttemptAt,
    this.lastError,
    this.lastErrorCategory,
    this.uidClaimed = false,
  });

  factory SyncQueueEntry.fromMap(Map<String, Object?> map) {
    return SyncQueueEntry(
      workspaceId: _string(map['workspaceId']),
      entityType: _string(map['entityType']),
      recordId: _string(map['recordId']),
      operation: _string(map['operation']),
      status: _string(map['status']),
      attemptCount: _int(map['attemptCount']),
      createdAt: _time(map['createdAt']),
      lastAttemptAt: _timeOrNull(map['lastAttemptAt']),
      nextAttemptAt: _timeOrNull(map['nextAttemptAt']),
      lastError: map['lastError']?.toString(),
      lastErrorCategory: map['lastErrorCategory']?.toString(),
      uidClaimed: map['uidClaimed'] == true,
    );
  }

  final String workspaceId;
  final String entityType;
  final String recordId;
  final String operation;
  final String status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final String? lastErrorCategory;

  /// The server sequence for this record's uId was already claimed, so a
  /// retry must not claim (and burn) another number.
  final bool uidClaimed;

  String get queueId => LocalRecord.keyOf(entityType, recordId);

  SyncQueueEntry copyWith({
    String? operation,
    String? status,
    int? attemptCount,
    DateTime? lastAttemptAt,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    String? lastError,
    String? lastErrorCategory,
    bool clearError = false,
    bool? uidClaimed,
  }) {
    return SyncQueueEntry(
      workspaceId: workspaceId,
      entityType: entityType,
      recordId: recordId,
      operation: operation ?? this.operation,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextAttemptAt:
          clearNextAttemptAt ? null : (nextAttemptAt ?? this.nextAttemptAt),
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastErrorCategory: clearError
          ? null
          : (lastErrorCategory ?? this.lastErrorCategory),
      uidClaimed: uidClaimed ?? this.uidClaimed,
    );
  }

  Map<String, Object?> toMap() => {
        'queueId': queueId,
        'workspaceId': workspaceId,
        'entityType': entityType,
        'recordId': recordId,
        'operation': operation,
        'status': status,
        'attemptCount': attemptCount,
        'createdAt': _iso(createdAt),
        'lastAttemptAt':
            lastAttemptAt == null ? null : _iso(lastAttemptAt!),
        'nextAttemptAt':
            nextAttemptAt == null ? null : _iso(nextAttemptAt!),
        'lastError': lastError,
        'lastErrorCategory': lastErrorCategory,
        'uidClaimed': uidClaimed,
      };
}

// ---------------------------------------------------------------------------
// Sync conflict - references and metadata only
// ---------------------------------------------------------------------------

class SyncConflict {
  const SyncConflict({
    required this.conflictId,
    required this.workspaceId,
    required this.entityType,
    required this.recordId,
    required this.conflictType,
    required this.status,
    required this.detectedAt,
    this.resolvedAt,
    this.resolution,
    this.detail,
  });

  factory SyncConflict.fromMap(Map<String, Object?> map) {
    return SyncConflict(
      conflictId: _string(map['conflictId']),
      workspaceId: _string(map['workspaceId']),
      entityType: _string(map['entityType']),
      recordId: _string(map['recordId']),
      conflictType: _string(map['conflictType']),
      status: _string(map['status']),
      detectedAt: _time(map['detectedAt']),
      resolvedAt: _timeOrNull(map['resolvedAt']),
      resolution: map['resolution']?.toString(),
      detail: map['detail']?.toString(),
    );
  }

  final String conflictId;
  final String workspaceId;
  final String entityType;
  final String recordId;
  final String conflictType;
  final String status;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final String? resolution;

  /// Short human-readable note (never a copy of the record).
  final String? detail;

  bool get isOpen => status == ConflictStatus.open;

  SyncConflict copyWith({
    String? conflictType,
    String? status,
    DateTime? resolvedAt,
    String? resolution,
    String? detail,
  }) {
    return SyncConflict(
      conflictId: conflictId,
      workspaceId: workspaceId,
      entityType: entityType,
      recordId: recordId,
      conflictType: conflictType ?? this.conflictType,
      status: status ?? this.status,
      detectedAt: detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolution: resolution ?? this.resolution,
      detail: detail ?? this.detail,
    );
  }

  Map<String, Object?> toMap() => {
        'conflictId': conflictId,
        'workspaceId': workspaceId,
        'entityType': entityType,
        'recordId': recordId,
        'conflictType': conflictType,
        'status': status,
        'detectedAt': _iso(detectedAt),
        'resolvedAt': resolvedAt == null ? null : _iso(resolvedAt!),
        'resolution': resolution,
        'detail': detail,
      };
}

// ---------------------------------------------------------------------------
// Local sequence
// ---------------------------------------------------------------------------

class LocalSequence {
  const LocalSequence({
    required this.entityKey,
    required this.scopeKey,
    required this.yearKey,
    required this.lastIssuedSequence,
    required this.lastKnownServerSequence,
    required this.updatedAt,
  });

  factory LocalSequence.fromMap(Map<String, Object?> map) {
    return LocalSequence(
      entityKey: _string(map['entityKey']),
      scopeKey: _string(map['scopeKey']),
      yearKey: _string(map['yearKey']),
      lastIssuedSequence: _int(map['lastIssuedSequence']),
      lastKnownServerSequence: _int(map['lastKnownServerSequence']),
      updatedAt: _time(map['updatedAt']),
    );
  }

  final String entityKey;
  final String scopeKey;
  final String yearKey;
  final int lastIssuedSequence;
  final int lastKnownServerSequence;
  final DateTime updatedAt;

  /// The next number this device may hand out.
  int get nextSequence => (lastIssuedSequence > lastKnownServerSequence
          ? lastIssuedSequence
          : lastKnownServerSequence) +
      1;

  Map<String, Object?> toMap() => {
        'entityKey': entityKey,
        'scopeKey': scopeKey,
        'yearKey': yearKey,
        'lastIssuedSequence': lastIssuedSequence,
        'lastKnownServerSequence': lastKnownServerSequence,
        'updatedAt': _iso(updatedAt),
      };
}
