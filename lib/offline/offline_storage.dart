import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../features/authentication/controllers/login_controllers.dart';
import '../services/sequences_service.dart';
import '../utils/exceptions/app_exceptions.dart';

import '../utils/constants/environment_config.dart';
import 'core/local_database.dart';
import 'core/workspace_access.dart';
import 'core/workspace_scope.dart';
import 'data/local_record_dao.dart';
import 'data/local_record_repository.dart';
import 'data/local_sequence_dao.dart';
import 'data/reference_snapshot_dao.dart';
import 'data/sync_conflict_dao.dart';
import 'data/sync_queue_dao.dart';
import 'data/workspace_repository.dart';
import 'offline_exceptions.dart';
import 'offline_models.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_remote_gateway.dart';
import 'sync/sync_adapter_registry.dart';
import 'uid/expense_uid_service.dart';

/// Single entry point to the offline workspace storage. Later stages (UID
/// service, sync engine, guards) reach the DAOs and repositories through
/// `OfflineStorage.instance`, the same pattern as `DataCacheService`.
class OfflineStorage {
  OfflineStorage._(this.local)
      : queue = SyncQueueDao(local.database),
        conflicts = SyncConflictDao(local.database),
        sequences = LocalSequenceDao(local.database),
        snapshots = ReferenceSnapshotDao(local.database),
        records = LocalRecordDao(local.database) {
    workspaces = WorkspaceRepository(
      database: local.database,
      records: records,
      queue: queue,
      conflicts: conflicts,
      snapshots: snapshots,
    );

    localRecords = LocalRecordRepository(
      database: local.database,
      workspaces: workspaces,
      records: records,
      queue: queue,
      conflicts: conflicts,
      snapshots: snapshots,
      onQueued: () {
        final engine = _syncEngine;
        if (engine != null) unawaited(engine.syncNow());
      },
    );
  }

  static OfflineStorage? _instance;

  final LocalDatabase local;
  final SyncQueueDao queue;
  final SyncConflictDao conflicts;
  final LocalSequenceDao sequences;
  final ReferenceSnapshotDao snapshots;
  final LocalRecordDao records;
  late final WorkspaceRepository workspaces;
  late final LocalRecordRepository localRecords;
  SyncEngine? _syncEngine;

  /// The single background sync worker for this local database. Access it
  /// only after app services (including SequenceService) are registered.
  SyncEngine get syncEngine => _syncEngine ??= SyncEngine(
        storage: this,
        remote: FirebaseSyncRemoteGateway(),
        sequences: SequenceService.instance,
        expenseUid: ExpenseUidService.forApp(),
        registry: SyncAdapterRegistry.standard(),
      );

  /// Opens the owner/vehicle workspace and resumes queued sync safely.
  /// Call after successful authentication and after a vehicle is selected.
  ///
  /// One workspace per environment and owner: opening it again for a
  /// different vehicle (or after the access profile changed) just refreshes
  /// the stored [access] - the owner's assigned vehicles and roles, which
  /// the repository enforces per record.
  Future<void> activateWorkspace(
    WorkspaceScope scope, {
    required String ownerPhone,
    WorkspaceAccess? access,
  }) {
    // Activations run one after another (startup, vehicle change, cache
    // init can all ask at once). The chain only orders them: a failed
    // activation never blocks the next one, so switching and recovery work.
    final run = _activationTail.then(
      (_) => _activate(scope, ownerPhone: ownerPhone, access: access),
    );
    _activationTail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _activationTail = Future<void>.value();

  Future<void> _activate(
    WorkspaceScope scope, {
    required String ownerPhone,
    WorkspaceAccess? access,
  }) async {
    try {
      await workspaces.open(scope, ownerPhone: ownerPhone, access: access);
      // Only entries of an interrupted run are reset; a sync already in
      // flight keeps its `syncing` entries.
      await syncEngine.recoverInterruptedEntries(scope.workspaceId);
      await syncEngine.start(scope);
      activationError = null;
    } catch (error) {
      activationError = AppException.messageOf(error);
      rethrow;
    }
  }

  /// Why the last [activateWorkspace] failed, or `null` after a successful
  /// one. For the UI: a workspace that could not be opened refuses local
  /// writes with a specific reason.
  static String? activationError;

  Future<void> syncNow({bool isManual = true}) => syncEngine.syncNow(isManual: isManual);

  /// Reference snapshots of [ownerUserId] live in the owner's workspace
  /// id. Use this for every snapshot read/write so the engine, the cache
  /// and the controllers agree on one namespace.
  static String snapshotNamespace(String ownerUserId) => WorkspaceScope.idFor(
        EnvironmentConfig.currentEnvironment.name,
        ownerUserId,
      );

  /// Sync health of everything the open workspace's owner has on this
  /// device. Zero when no workspace is open.
  Future<WorkspaceCounts> pendingCounts() => workspaces.currentCounts();

  Future<int> retryFailedSync() async {
    final info = await workspaces.current();
    if (info == null) return 0;
    final retried = await queue.retryFailed(info.workspaceId);
    if (retried > 0) unawaited(syncEngine.syncNow());
    return retried;
  }

  Database get database => local.database;

  static bool get isAvailable => _instance != null;

  static OfflineStorage get instance {
    final storage = _instance;
    if (storage == null) throw const OfflineStorageException.unavailable();
    return storage;
  }

  static OfflineStorageException? _initializationError;

  /// Why the local database could not be opened, or `null` when it opened
  /// (or was never attempted). While this is set [isAvailable] is false and
  /// the app runs on its existing online path; nothing local is lost, since
  /// the file is never deleted or recreated on failure.
  static OfflineStorageException? get initializationError =>
      _initializationError;

  /// Opens the database for the running environment. Called once at app
  /// start; safe to call again (returns the open instance). Failures are
  /// recorded in [initializationError] and rethrown - never swallowed here.
  static Future<OfflineStorage> initialize() {
    return initializeWith(
      () => LocalDatabase.open(
        environmentName: EnvironmentConfig.currentEnvironment.name,
      ),
    );
  }

  @visibleForTesting
  static Future<OfflineStorage> initializeWith(
    Future<LocalDatabase> Function() opener,
  ) async {
    final existing = _instance;
    if (existing != null) return existing;

    try {
      final local = await opener();
      _initializationError = null;
      return _instance = OfflineStorage._(local);
    } catch (error, stack) {
      final failure = error is OfflineStorageException
          ? error
          : OfflineStorageException.unavailable(details: error);
      _initializationError = failure;
      Error.throwWithStackTrace(failure, stack);
    }
  }

  /// Makes a failed start visible (console / crash reporting) instead of
  /// printing a notice and moving on. The app keeps running without offline
  /// storage.
  static void reportInitializationFailure(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'offline storage',
        context: ErrorDescription(
          'while opening the local Sembast database; offline mode is '
          'unavailable for this session',
        ),
      ),
    );
  }

  /// Storage over an already opened database (tests). Does not replace
  /// [instance].
  static OfflineStorage forDatabase(Database database) {
    return OfflineStorage._(LocalDatabase.fromDatabase(database));
  }

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
    _initializationError = null;
    lastSaveError = null;
    activationError = null;
  }

  /// The reason the most recent [saveLocal] did not save, or `null`.
  static String? lastSaveError;

  /// Why offline storage cannot be used right now, or `null` when it can.
  /// Shown to the user instead of letting a missing database look like a
  /// working one.
  static String? get unavailableReason {
    if (isAvailable) return null;
    return _initializationError?.message ??
        const OfflineStorageException.unavailable().message;
  }

  /// Throws the specific reason when the local database could not be
  /// opened. Every save path calls this instead of skipping persistence
  /// silently when offline storage is unavailable.
  static void requireAvailable() {
    if (isAvailable) return;
    throw _initializationError ?? const OfflineStorageException.unavailable();
  }

  /// Whether [error] means the LOCAL save failed (storage, workspace scope,
  /// access or record validation) - as opposed to an unrelated failure such
  /// as a sequence lookup.
  static bool isLocalSaveFailure(Object error) =>
      error is OfflineStorageException ||
      error is OfflineScopeException ||
      error is OfflineDataException ||
      error is WorkspaceOwnershipException;

  /// [error] itself when it already is a local save failure, otherwise an
  /// [OfflineStorageException.saveFailed] carrying it. Lets a catch block
  /// rethrow something callers can recognise with [isLocalSaveFailure].
  static Object asSaveFailure(Object error) => isLocalSaveFailure(error)
      ? error
      : OfflineStorageException.saveFailed(details: error);

  /// Firebase Auth uid of the signed-in session. The business record id
  /// (`users/{id}`) is a different identity and is NEVER substituted for it;
  /// without an Auth session this throws [OfflineScopeException].
  static String requireAuthUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      throw const OfflineScopeException.noWorkspace(
        details: 'no Firebase Auth session',
      );
    }
    return uid;
  }

  /// The workspace scope of the signed-in user: owner = resolved
  /// `authUsers/{uid}/recordId` user (`LoginController.loginUser.id`), auth
  /// identity = the Firebase Auth uid. Single place every caller builds its
  /// scope from.
  static WorkspaceScope currentScope({String vehicleId = ''}) {
    final ownerUserId = LoginController.loginUser.id.trim();
    if (ownerUserId.isEmpty) {
      throw const OfflineScopeException.noWorkspace(
        details: 'no signed-in user',
      );
    }
    return WorkspaceScope.forCurrentEnvironment(
      ownerUserId: ownerUserId,
      authUid: requireAuthUid(),
      vehicleId: vehicleId,
    );
  }

  /// Throws the specific reason when the open workspace cannot accept writes
  /// of every type in [entityTypes] (no workspace, locked, no access profile
  /// or a role that may not write it). Lets a multi-record operation fail
  /// before it writes anything.
  Future<void> requireWritable(Iterable<String> entityTypes) async {
    final info = await workspaces.current();
    if (info == null) throw const OfflineScopeException.noWorkspace();
    if (info.isLocked) throw const OfflineScopeException.locked();
    final access = info.access;
    if (access == null) {
      throw const OfflineScopeException.notAllowed(
        details: 'the workspace has no access profile',
      );
    }
    for (final type in entityTypes) {
      if (!access.canWrite(type)) {
        throw OfflineScopeException.notAllowed(
          details: '${access.userType} may not write $type',
        );
      }
    }
  }

  /// Saves a record to the local workspace and queues it for sync.
  ///
  /// Returns `true` when the record was saved. Errors are logged and
  /// recorded in [lastSaveError] and reported as `false`; existing callers
  /// are not interrupted (their workflows are unchanged), but a failed save
  /// is never invisible.
  ///
  /// [vehicleId] is accepted for existing callers but does not choose a
  /// workspace; the record's own `vehicleId` field is what the access
  /// policy checks.
  static Future<bool> saveLocal({
    required String entityType,
    required String recordId,
    required Map<String, dynamic> data,
    bool isNew = false,
    String? vehicleId,
  }) async {
    if (!isAvailable) {
      lastSaveError = unavailableReason;
      return false;
    }
    try {
      final scope = currentScope();

      await instance.localRecords.saveRecord(
        scope,
        entityType: entityType,
        recordId: recordId,
        data: data,
        isNew: isNew,
      );
      lastSaveError = null;
      return true;
    } catch (error, stack) {
      lastSaveError = AppException.messageOf(error);
      debugPrint(
        'OfflineStorage saveLocal failed for $entityType/$recordId: '
        '$error\n$stack',
      );
      return false;
    }
  }

  /// Like [saveLocal], but a failure is thrown (as a local save failure with
  /// the specific reason) instead of reported as `false`. Use it where the
  /// caller would otherwise show success, update a cache or close a dialog
  /// after a save that did not happen.
  static Future<void> saveLocalOrThrow({
    required String entityType,
    required String recordId,
    required Map<String, dynamic> data,
    bool isNew = false,
  }) async {
    try {
      requireAvailable();
      await instance.localRecords.saveRecord(
        currentScope(),
        entityType: entityType,
        recordId: recordId,
        data: data,
        isNew: isNew,
      );
      lastSaveError = null;
    } catch (error, stack) {
      lastSaveError = AppException.messageOf(error);
      debugPrint(
        'OfflineStorage saveLocalOrThrow failed for $entityType/$recordId: '
        '$error\n$stack',
      );
      Error.throwWithStackTrace(asSaveFailure(error), stack);
    }
  }

  Future<void> close() async {
    await _syncEngine?.dispose();
    await local.close();
    if (identical(_instance, this)) _instance = null;
  }
}
