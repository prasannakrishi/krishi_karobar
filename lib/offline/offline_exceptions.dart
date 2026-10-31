import '../utils/exceptions/app_exceptions.dart';

/// Local offline storage could not be opened or used.
class OfflineStorageException extends AppException {
  const OfflineStorageException(
    super.message, {
    super.code,
    super.details,
  });

  const OfflineStorageException.unavailable({Object? details})
      : this(
          'Offline storage is not available on this device.',
          code: 'offline-storage-unavailable',
          details: details,
        );

  const OfflineStorageException.migrationFailed({Object? details})
      : this(
          'The offline database could not be upgraded. Existing local data '
          'was left untouched.',
          code: 'offline-migration-failed',
          details: details,
        );
}

/// A local read/write was attempted outside the current workspace
/// (wrong user, wrong vehicle, no workspace, or a locked workspace).
class OfflineScopeException extends AppException {
  const OfflineScopeException(
    super.message, {
    super.code,
    super.details,
  });

  const OfflineScopeException.noWorkspace({Object? details})
      : this(
          'No offline workspace is open for this user and vehicle.',
          code: 'workspace-missing',
          details: details,
        );

  const OfflineScopeException.mismatch({Object? details})
      : this(
          'This data belongs to a different user or vehicle workspace.',
          code: 'workspace-mismatch',
          details: details,
        );

  const OfflineScopeException.invalid({Object? details})
      : this(
          'The offline workspace identity is invalid.',
          code: 'workspace-invalid',
          details: details,
        );

  const OfflineScopeException.notAllowed({Object? details})
      : this(
          'You are not allowed to use this vehicle or save this data offline.',
          code: 'workspace-not-allowed',
          details: details,
        );

  const OfflineScopeException.locked({Object? details})
      : this(
          'The offline workspace is locked until its data is synchronized.',
          code: 'workspace-locked',
          details: details,
        );
}

/// Opening a workspace was refused because another owner's (or another
/// vehicle's) unsynchronized data is still on the device.
class WorkspaceOwnershipException extends AppException {
  const WorkspaceOwnershipException(
    super.message, {
    super.code,
    super.details,
  });

  const WorkspaceOwnershipException.differentOwner({Object? details})
      : this(
          'Unsynchronized data from another user exists on this device. '
          'That user must sign in and synchronize it first.',
          code: 'workspace-owner-mismatch',
          details: details,
        );

  const WorkspaceOwnershipException.vehicleSwitchPending({Object? details})
      : this(
          'Unsynchronized data exists for the current vehicle. '
          'Synchronize it before switching vehicles.',
          code: 'workspace-vehicle-pending',
          details: details,
        );

  const WorkspaceOwnershipException.differentAuthIdentity({Object? details})
      : this(
          'The signed-in account does not match the account that owns the '
          'unsynchronized data on this device.',
          code: 'workspace-auth-mismatch',
          details: details,
        );
}

/// A record handed to the local database cannot be stored safely.
class OfflineDataException extends AppException {
  const OfflineDataException(
    super.message, {
    super.code,
    super.details,
  });

  const OfflineDataException.invalid({String? message, Object? details})
      : this(
          message ?? 'The offline record is invalid and was not saved.',
          code: 'offline-invalid-record',
          details: details,
        );

  const OfflineDataException.stale({Object? details})
      : this(
          'A newer value for this record is already saved on this device. '
          'The older change was not applied.',
          code: 'offline-record-stale',
          details: details,
        );

  const OfflineDataException.tombstoned({Object? details})
      : this(
          'This record was deleted locally and cannot be edited. Its '
          'deletion is waiting to be synchronized.',
          code: 'offline-record-tombstoned',
          details: details,
        );

  const OfflineDataException.missingRecord({Object? details})
      : this(
          'The offline record was not found in the local workspace.',
          code: 'offline-record-missing',
          details: details,
        );
}

/// An Expense uId could not be formatted, parsed or reconciled.
class ExpenseUidException extends AppException {
  const ExpenseUidException(
    super.message, {
    super.code,
    super.details,
  });

  const ExpenseUidException.invalid({String? message, Object? details})
      : this(
          message ?? 'The Expense uId is invalid.',
          code: 'expense-uid-invalid',
          details: details,
        );

  const ExpenseUidException.counterUnreadable({Object? details})
      : this(
          'The Expense sequence on the server is not a valid number.',
          code: 'expense-uid-counter-invalid',
          details: details,
        );
}

/// A record could not be prepared for sync (missing reference data, or a
/// provisional uId that was never resolved).
class SyncPreparationException extends AppException {
  const SyncPreparationException(
    super.message, {
    super.code,
    super.details,
  });

  factory SyncPreparationException.missingReference({
    required String type,
    required String id,
  }) {
    return SyncPreparationException(
      'Required $type data ($id) is missing on this device. Connect to the '
      'internet to refresh it, then sync again.',
      code: 'sync-reference-missing',
      details: '$type/$id',
    );
  }

  factory SyncPreparationException.pendingUid({required String recordId}) {
    return SyncPreparationException(
      'The record still has a pending uId and cannot be sent yet.',
      code: 'sync-uid-pending',
      details: recordId,
    );
  }
}
