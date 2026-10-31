import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../features/activity_monitor/controllers/monitor_controller.dart';
import '../features/authentication/controllers/login_controllers.dart';
import '../models/models.dart';
import '../utils/exceptions/app_exceptions.dart';
import '../utils/helper/helper_widgets.dart';
import '../utils/helper/nepali_date_time.dart';
import '../utils/helper/network_manager.dart';
import 'authorization_service.dart';
import 'data_cache_service.dart';
import 'firebase_service.dart';
import 'user_profile_resolver.dart';

class SessionRestoreResult {
  const SessionRestoreResult.restored()
      : isRestored = true,
        message = null;

  const SessionRestoreResult.loginRequired([this.message]) : isRestored = false;

  final bool isRestored;
  final String? message;
}

/// One login per Nepal calendar day.
///
/// GetStorage holds only lightweight session markers. Firebase Auth stays
/// the authority: a stored `loggedIn` flag is never trusted on its own.
class SessionService extends GetxService with WidgetsBindingObserver {
  static SessionService get instance => Get.find<SessionService>();

  static const String _loggedInKey = 'loggedIn';
  static const String _userIdKey = 'userId';
  static const String _loginDateKey = 'loginDate';
  static const String _userSnapshotKey = 'sessionUser';

  final GetStorage _storage = GetStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();

  Timer? _midnightTimer;
  Worker? _activityWatcher;
  Worker? _connectivityWatcher;

  bool _isExpiring = false;
  bool _activityProtected = false;
  bool _warningOpen = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _activityWatcher?.dispose();
    _connectivityWatcher?.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkSession();
    }
  }

  // ---------------------------------------------------------------------------
  // Session state
  // ---------------------------------------------------------------------------

  /// Current calendar date in Nepal Standard Time, e.g. "2026-10-01".
  String get currentNepalDate {
    final nepal = toNepalStandardTime(DateTime.now());
    final month = nepal.month.toString().padLeft(2, '0');
    final day = nepal.day.toString().padLeft(2, '0');
    return '${nepal.year.toString().padLeft(4, '0')}-$month-$day';
  }

  bool get hasLocalSession {
    final userId = _storage.read<String>(_userIdKey) ?? '';
    return _storage.read<bool>(_loggedInKey) == true && userId.isNotEmpty;
  }

  bool get _isSessionDateCurrent =>
      _storage.read<String>(_loginDateKey) == currentNepalDate;

  void startSession(UserModel user) {
    _storage.write(_loggedInKey, true);
    _storage.write(_userIdKey, user.id);
    _storage.write(_loginDateKey, currentNepalDate);
    _storage.write(_userSnapshotKey, user.toMap());
    _activityProtected = false;
    _scheduleMidnightCheck();
  }

  void updateUserSnapshot(UserModel user) {
    _storage.write(_userSnapshotKey, user.toMap());
  }

  void clearSession() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
    _activityWatcher?.dispose();
    _activityWatcher = null;
    _connectivityWatcher?.dispose();
    _connectivityWatcher = null;
    _activityProtected = false;

    _storage.remove(_loggedInKey);
    _storage.remove(_userIdKey);
    _storage.remove(_loginDateKey);
    _storage.remove(_userSnapshotKey);
  }

  // ---------------------------------------------------------------------------
  // Startup restore
  // ---------------------------------------------------------------------------

  Future<SessionRestoreResult> restore() async {
    try {
      return await _restore();
    } catch (error) {
      return _rejectRestore(AppException.messageOf(error));
    }
  }

  Future<SessionRestoreResult> _restore() async {
    if (!hasLocalSession) {
      return const SessionRestoreResult.loginRequired();
    }

    final storedUserId = _storage.read<String>(_userIdKey) ?? '';
    final cached = _cachedProfile(storedUserId);

    if (cached == null) {
      return const SessionRestoreResult.loginRequired();
    }

    // Instantly restore session from local storage for instant cold start
    LoginController.loginUser = cached;

    if (!Get.isRegistered<DataCacheService>()) {
      Get.put(DataCacheService());
    }

    try {
      await DataCacheService.instance.initializeForUser(cached);
    } catch (error) {
      debugPrint('SessionService local cache init: $error');
    }

    if (!_isSessionDateCurrent) {
      if (_hasLiveActivity) {
        _activityProtected = true;
        _scheduleMidnightCheck();
        _watchForActivityCompletion();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showRunningActivityWarning(),
        );
        return const SessionRestoreResult.restored();
      }

      return _rejectRestore(
        'Your session from the previous day has ended. Please sign in again.',
      );
    }

    _scheduleMidnightCheck();

    // Refresh profile in background asynchronously without blocking startup
    _backgroundProfileRefresh();

    return const SessionRestoreResult.restored();
  }

  void _backgroundProfileRefresh() {
    _currentFirebaseUser().then((firebaseUser) {
      if (firebaseUser != null) {
        UserProfileResolver().resolve(firebaseUser).then((profile) {
          _storage.write(_userSnapshotKey, profile.toMap());
          LoginController.loginUser = profile;
        }).catchError((_) {});
      }
    }).catchError((_) {});
  }

  Future<User?> _currentFirebaseUser() async {
    try {
      return await _auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      return _auth.currentUser;
    }
  }

  UserModel? _cachedProfile(String userId) {
    final raw = _storage.read<dynamic>(_userSnapshotKey);
    if (raw is! Map) return null;

    try {
      final user = UserModel.fromMap(Map<String, dynamic>.from(raw));
      if (user.id != userId || !Authz.isSessionValid(actor: user)) return null;
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<SessionRestoreResult> _rejectRestore(String message) async {
    await _discardLocalState();
    return SessionRestoreResult.loginRequired(message);
  }

  Future<void> _discardLocalState() async {
    clearSession();

    try {
      if (Get.isRegistered<DataCacheService>()) {
        await DataCacheService.instance.clearCache();
        Get.delete<DataCacheService>();
      }
    } catch (error) {
      debugPrint('SessionService cache clear: $error');
    }

    LoginController.loginUser = UserModel.empty();

    _storage.remove('selectedOrganization');
    _storage.remove('selectedVehicle');
    _storage.remove('default_vehicle');

    try {
      await _auth.signOut();
    } catch (error) {
      debugPrint('SessionService signOut: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Date-change detection (startup, resume, midnight while open)
  // ---------------------------------------------------------------------------

  /// One-shot timer to the next Nepal midnight; re-armed on every check.
  void _scheduleMidnightCheck() {
    _midnightTimer?.cancel();

    final nepal = toNepalStandardTime(DateTime.now());
    final nextMidnight = DateTime.utc(nepal.year, nepal.month, nepal.day + 1);
    final wait = nextMidnight.difference(nepal) + const Duration(seconds: 1);

    _midnightTimer = Timer(wait, () {
      checkSession();
    });
  }

  Future<void> checkSession() async {
    if (!hasLocalSession || _isExpiring) return;

    _scheduleMidnightCheck();

    if (_isSessionDateCurrent) return;

    if (_hasLiveActivity) {
      _activityProtected = true;
      _watchForActivityCompletion();
      _showRunningActivityWarning();
      return;
    }

    await _expireWhenSafe();
  }

  // ---------------------------------------------------------------------------
  // Running-activity protection
  // ---------------------------------------------------------------------------

  /// True while the signed-in user has an activity they started that is still
  /// running/paused (stopped-but-unsaved activities are still "running" in
  /// the database until Save completes).
  bool get _hasLiveActivity {
    final userId = LoginController.loginUser.id;
    if (userId.isEmpty) return false;

    if (Get.isRegistered<MonitorController>() &&
        Get.find<MonitorController>().currentActivityId.value != null) {
      return true;
    }

    if (!Get.isRegistered<DataCacheService>()) return false;

    return DataCacheService.instance.activities.values.any(
      (activity) =>
          ActivityStatus.liveStates.contains(activity.status) &&
          activity.startedByUserId == userId,
    );
  }

  bool get _isFinalizingActivity =>
      Get.isRegistered<MonitorController>() &&
      Get.find<MonitorController>().isFinalizingActivity;

  void _watchForActivityCompletion() {
    _activityWatcher?.dispose();
    _connectivityWatcher?.dispose();

    if (Get.isRegistered<DataCacheService>()) {
      _activityWatcher = ever(
        DataCacheService.instance.activities,
        (_) => _onProtectedStateChanged(),
      );
    }

    if (Get.isRegistered<NetworkManager>()) {
      _connectivityWatcher = ever(
        NetworkManager.instance.connectionStatus,
        (_) => _onProtectedStateChanged(),
      );
    }
  }

  void _onProtectedStateChanged() {
    if (!_activityProtected || _isExpiring || _hasLiveActivity) return;
    _expireWhenSafe();
  }

  void _showRunningActivityWarning() {
    if (_warningOpen || Get.context == null) return;

    _warningOpen = true;

    Get.dialog<void>(
      AlertDialog(
        title: const Text('New day has started'),
        content: const Text(
          'New day has started. An Activity is still running.\n'
          'Please stop and save the current Activity before the session expires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Continue Activity'),
          ),
        ],
      ),
    ).whenComplete(() => _warningOpen = false);
  }

  // ---------------------------------------------------------------------------
  // Expiry
  // ---------------------------------------------------------------------------

  Future<void> _expireWhenSafe() async {
    if (_isExpiring) return;
    _isExpiring = true;

    try {
      if (_activityProtected && !await _isSafeToSignOut()) {
        return;
      }

      await _expireNow();
    } finally {
      _isExpiring = false;
    }
  }

  /// After a protected activity, sign-out is deferred until the save's
  /// follow-up writes finished and the device is online, so queued writes are
  /// not rejected by rules once Firebase Auth is signed out.
  Future<bool> _isSafeToSignOut() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    while (_isFinalizingActivity && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if (_isFinalizingActivity) return false;
    if (!await NetworkManager.instance.isConnected()) return false;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return true;

    try {
      // A server round-trip after the save's writes: ordered on the same
      // connection, so it only completes once earlier writes were sent.
      await _firebaseService.getRecordById('authUsers', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _expireNow() async {
    final controller = Get.isRegistered<LoginController>()
        ? Get.find<LoginController>()
        : Get.put(LoginController());

    await controller.logout();

    warningSnackBar(
      title: 'Session expired',
      message: 'A new day has started. Please sign in again.',
    );
  }
}
