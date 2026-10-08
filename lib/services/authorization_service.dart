import '../features/authentication/controllers/login_controllers.dart';
import '../models/models.dart';
import '../utils/exceptions/app_exceptions.dart';

/// Granular, [module].[action] permission constants.
///
/// Only permissions the app actually has a use for today are defined here
/// (spec section 4: "do not create unnecessary permissions"). Finance and
/// Report modules don't exist in this app yet, so their permissions are left
/// out until those modules are built - see AuthorizationService doc comment.
class Permissions {
  Permissions._();

  static const userView = 'user.view';
  static const userCreate = 'user.create';
  static const userEdit = 'user.edit';
  static const userDelete = 'user.delete';
  static const userActivate = 'user.activate';
  static const userDeactivate = 'user.deactivate';
  static const userAssignRole = 'user.assignRole';

  static const vehicleView = 'vehicle.view';
  static const vehicleCreate = 'vehicle.create';
  static const vehicleEdit = 'vehicle.edit';
  static const vehicleDelete = 'vehicle.delete';
  static const vehicleActivate = 'vehicle.activate';
  static const vehicleDeactivate = 'vehicle.deactivate';

  static const serviceView = 'service.view';
  static const serviceCreate = 'service.create';
  static const serviceEdit = 'service.edit';
  static const serviceDelete = 'service.delete';
  static const serviceActivate = 'service.activate';
  static const serviceDeactivate = 'service.deactivate';

  static const customerView = 'customer.view';
  static const customerCreate = 'customer.create';
  static const customerEdit = 'customer.edit';
  static const customerDelete = 'customer.delete';

  static const activityView = 'activity.view';
  static const activityCreate = 'activity.create';
  static const activityEdit = 'activity.edit';
  static const activityStart = 'activity.start';
  static const activityComplete = 'activity.complete';
  static const activityCancel = 'activity.cancel';
  static const activityViewGps = 'activity.viewGps';

  static const settingsView = 'settings.view';
  static const settingsEdit = 'settings.edit';

  static const auditView = 'audit.view';
  static const paymentCreate = 'payment.create';
  static const expenseView = 'expense.view';
  static const expenseCreate = 'expense.create';
  static const expenseEdit = 'expense.edit';
  static const expenseDelete = 'expense.delete';
}

/// Role -> permission matrix (spec sections 5 & 7, trimmed to modules that
/// actually exist in this app: user, vehicle, service, activity, settings,
/// audit). When Finance/Reports modules are added, extend this map rather
/// than scattering new checks around the app.
class _RolePermissions {
  static const Map<String, Set<String>> matrix = {
    UserRoles.superAdmin: {
      Permissions.userView, Permissions.userCreate, Permissions.userEdit,
      Permissions.userDelete, Permissions.userActivate,
      Permissions.userDeactivate, Permissions.userAssignRole,
      Permissions.vehicleView, Permissions.vehicleCreate,
      Permissions.vehicleEdit, Permissions.vehicleDelete,
      Permissions.vehicleActivate, Permissions.vehicleDeactivate,
      Permissions.serviceView, Permissions.serviceCreate,
      Permissions.serviceEdit, Permissions.serviceDelete,
      Permissions.serviceActivate, Permissions.serviceDeactivate,
      Permissions.customerView, Permissions.customerCreate,
      Permissions.customerEdit, Permissions.customerDelete,
      Permissions.activityView, Permissions.activityCreate,
      Permissions.activityEdit, Permissions.activityStart,
      Permissions.activityComplete, Permissions.activityCancel,
      Permissions.activityViewGps,
      Permissions.settingsView, Permissions.settingsEdit,
      Permissions.auditView,
      Permissions.paymentCreate,
      Permissions.expenseView, Permissions.expenseCreate,
      Permissions.expenseEdit, Permissions.expenseDelete,
    },
    UserRoles.admin: {
      Permissions.userView, Permissions.userCreate, Permissions.userEdit,
      Permissions.userActivate, Permissions.userDeactivate,
      Permissions.vehicleView, Permissions.vehicleCreate,
      Permissions.vehicleEdit, Permissions.vehicleActivate,
      Permissions.vehicleDeactivate,
      Permissions.serviceView, Permissions.serviceCreate,
      Permissions.serviceEdit, Permissions.serviceActivate,
      Permissions.serviceDeactivate,
      Permissions.customerView, Permissions.customerCreate,
      Permissions.customerEdit, Permissions.customerDelete,
      Permissions.activityView, Permissions.activityCreate,
      Permissions.activityEdit, Permissions.activityStart,
      Permissions.activityComplete, Permissions.activityCancel,
      Permissions.activityViewGps,
      Permissions.settingsView, Permissions.settingsEdit,
      Permissions.paymentCreate,
      Permissions.expenseView, Permissions.expenseCreate,
      Permissions.expenseEdit, Permissions.expenseDelete,
    },
    UserRoles.manager: {
      Permissions.userView,
      Permissions.vehicleView, Permissions.vehicleEdit,
      Permissions.serviceView, Permissions.serviceCreate,
      Permissions.serviceEdit,
      Permissions.customerView, Permissions.customerCreate,
      Permissions.customerEdit, Permissions.customerDelete,
      Permissions.activityView, Permissions.activityCreate,
      Permissions.activityEdit, Permissions.activityStart,
      Permissions.activityComplete, Permissions.activityCancel,
      Permissions.settingsView,
      Permissions.paymentCreate,
      Permissions.expenseView, Permissions.expenseCreate,
      Permissions.expenseEdit,
    },
    UserRoles.accountant: {
      Permissions.userView,
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView,
      Permissions.paymentCreate,
      Permissions.expenseView,
      // finance.* intentionally omitted - no finance module yet.
    },
    UserRoles.supervisor: {
      Permissions.userView,
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView, Permissions.activityStart,
      Permissions.activityCreate,
      Permissions.activityEdit, Permissions.activityComplete, Permissions.activityCancel,
      Permissions.paymentCreate,
      Permissions.expenseView, Permissions.expenseCreate,
    },
    UserRoles.driver: {
      Permissions.userView,
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView, Permissions.activityStart,
      Permissions.activityCreate,
      Permissions.activityEdit, Permissions.activityComplete, Permissions.activityCancel,
      Permissions.paymentCreate,
      Permissions.expenseView, Permissions.expenseCreate,
    },
    UserRoles.vehicleOwner: {
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView,
      Permissions.expenseView,
    },
    UserRoles.viewer: {
      Permissions.userView,
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView,
      Permissions.settingsView,
      Permissions.expenseView,
    },
  };

  static Set<String> forRoles(List<String> roles) {
    final result = <String>{};
    for (final role in roles) {
      result.addAll(matrix[role] ?? const {});
    }
    return result;
  }
}

/// Centralized authorization: AUTHENTICATION -> USER TYPE -> ROLE ->
/// PERMISSION -> DATA SCOPE -> BUSINESS RULE (spec section 3/15).
///
/// This is the ONLY place permission logic should live. Screens/widgets
/// should call `Authz.can(...)` etc. instead of checking
/// `role == 'admin'` inline.
///
/// IMPORTANT: this is CLIENT-SIDE UI gating only (spec section 17/18) - it
/// hides/shows buttons and blocks screens for a well-behaved client. It is
/// NOT the security boundary. The Realtime Database rules (see
/// `firebase_rtdb.rules.json` provided separately) are what actually stop a
/// malicious client from writing data it shouldn't.
/// Centralized authorization: AUTHENTICATION -> ACCOUNT STATUS -> USER TYPE
/// -> ROLE -> PERMISSION -> RECORD SCOPE.
///
/// This is the ONLY place permission logic lives. Screens call `Authz.can(...)`
/// to hide actions; controllers/services call the `require*` methods, which
/// throw a classified [AppException] so an unauthorized operation never
/// reaches Firebase.
///
/// Client-side authorization is not the security boundary - the Realtime
/// Database rules (`firebase_rtdb.rules.json`) are.
class Authz {
  Authz._();

  static UserModel get _user => LoginController.loginUser;

  /// Every check can be evaluated for an explicit [actor] (used by
  /// DataCacheService while a session is being established) and falls back
  /// to the signed-in user otherwise.
  static UserModel _resolve(UserModel? actor) => actor ?? _user;

  static String _status(UserModel user) => user.status.trim().toLowerCase();

  static bool isAuthenticated({UserModel? actor}) =>
      _resolve(actor).id.trim().isNotEmpty;

  static bool isActive({UserModel? actor}) =>
      _status(_resolve(actor)) == 'active';

  static bool isSuspended({UserModel? actor}) =>
      _status(_resolve(actor)) == 'suspended';

  /// True if the session is allowed to do anything at all.
  static bool isSessionValid({UserModel? actor}) =>
      isAuthenticated(actor: actor) && isActive(actor: actor);

  static bool hasUserType(String userType, {UserModel? actor}) =>
      _resolve(actor).userType == userType;

  static bool hasRole(String role, {UserModel? actor}) =>
      _resolve(actor).hasRole(role);

  static bool hasAnyRole(Iterable<String> roles, {UserModel? actor}) {
    final user = _resolve(actor);
    return roles.any(user.hasRole);
  }

  static Set<String> _permissionsFor(UserModel user) {
    if (!isSessionValid(actor: user) || user.isGuest) return const {};
    return _RolePermissions.forRoles(user.roles);
  }

  /// Core check: authentication + active status + permission grant.
  static bool can(String permission, {UserModel? actor}) {
    return _permissionsFor(_resolve(actor)).contains(permission);
  }

  static bool canAny(List<String> permissions, {UserModel? actor}) =>
      permissions.any((p) => can(p, actor: actor));

  static bool canAll(List<String> permissions, {UserModel? actor}) =>
      permissions.every((p) => can(p, actor: actor));

  static bool canAccessModule(String modulePrefix, {UserModel? actor}) {
    return _permissionsFor(
      _resolve(actor),
    ).any((p) => p.startsWith('$modulePrefix.'));
  }

  // ---------------------------------------------------------------------
  // REQUIRE* - throwing guards for controllers and services.
  // ---------------------------------------------------------------------

  static UserModel requireAuthenticated({UserModel? actor}) {
    final user = _resolve(actor);

    if (user.id.trim().isEmpty) {
      throw const AuthenticationException.required();
    }

    return user;
  }

  static UserModel requireActiveUser({UserModel? actor}) {
    final user = requireAuthenticated(actor: actor);
    final status = _status(user);

    if (status == 'suspended') {
      throw const AuthenticationException.suspendedAccount();
    }

    if (status != 'active') {
      throw const AuthenticationException.inactiveAccount();
    }

    return user;
  }

  static UserModel requirePermission(String permission, {UserModel? actor}) {
    final user = requireActiveUser(actor: actor);

    if (!_permissionsFor(user).contains(permission)) {
      throw AuthorizationException.permission(details: permission);
    }

    return user;
  }

  /// Record-scope guard. [allowed] is the outcome of the matching `can*`
  /// check; [recordType]/[recordId] are debug-only context.
  static void requireRecordAccess(
      bool allowed, {
        String? recordType,
        String? recordId,
      }) {
    if (allowed) return;

    throw RecordAccessException(
      details: '${recordType ?? 'record'}:${recordId ?? '-'}',
    );
  }

  static void requireVehicleAccess(
      VehicleModel vehicle, {
        String permission = Permissions.vehicleView,
        UserModel? actor,
      }) {
    requirePermission(permission, actor: actor);

    requireRecordAccess(
      canViewVehicle(vehicle, actor: actor),
      recordType: 'vehicle',
      recordId: vehicle.id,
    );
  }

  static void requireActivityAccess(
      ActivityModel activity, {
        VehicleModel? vehicle,
        UserModel? actor,
      }) {
    requirePermission(Permissions.activityView, actor: actor);

    requireRecordAccess(
      canViewActivity(activity, vehicle, actor: actor),
      recordType: 'activity',
      recordId: activity.id,
    );
  }

  /// Only the user who started an activity may control it.
  static void requireActivityControl(
      ActivityModel activity, {
        UserModel? actor,
      }) {
    requireActiveUser(actor: actor);

    requireRecordAccess(
      canControlActivity(activity, actor: actor),
      recordType: 'activity',
      recordId: activity.id,
    );
  }

  // ---------------------------------------------------------------------
  // DATA SCOPE HELPERS
  // Permission alone is not enough - these add the "is this MY record"
  // check on top of the raw permission.
  // ---------------------------------------------------------------------

  /// True when the user's vehicle access is limited to an explicit
  /// assignment list rather than the whole fleet.
  static bool isVehicleScoped({UserModel? actor}) {
    final user = _resolve(actor);

    if (user.hasAllVehicleAccess) return false;
    if (user.isExternal) return true;

    return user.hasRole(UserRoles.driver) ||
        user.hasRole(UserRoles.supervisor) ||
        user.hasRole(UserRoles.vehicleOwner);
  }

  /// Vehicle Owners/Drivers/External users may only see vehicles assigned
  /// to them; everyone else with vehicle.view sees every vehicle.
  static bool canViewVehicle(VehicleModel vehicle, {UserModel? actor}) {
    if (!can(Permissions.vehicleView, actor: actor)) return false;

    final user = _resolve(actor);

    if (!isVehicleScoped(actor: user)) return true;

    return vehicle.ownerId == user.id ||
        user.assignedVehicleIds.contains(vehicle.id);
  }

  static bool canEditVehicle(VehicleModel vehicle, {UserModel? actor}) {
    if (!can(Permissions.vehicleEdit, actor: actor)) return false;
    return canViewVehicle(vehicle, actor: actor);
  }

  static bool canDeleteVehicle(VehicleModel vehicle, {UserModel? actor}) {
    if (!can(Permissions.vehicleDelete, actor: actor)) return false;
    return canViewVehicle(vehicle, actor: actor);
  }

  /// Drivers/Vehicle Owners may only act on activities tied to a vehicle
  /// they're scoped to; everyone else with the base permission can proceed.
  static bool canManageActivity(
      String permission, {
        String? vehicleId,
        UserModel? actor,
      }) {
    if (!can(permission, actor: actor)) return false;
    if (vehicleId == null) return true;

    final user = _resolve(actor);

    if (!isVehicleScoped(actor: user)) return true;

    return user.assignedVehicleIds.contains(vehicleId);
  }

  // ---------------------------------------------------------------------
  // RECORD-LEVEL ACCESS
  // ---------------------------------------------------------------------

  static bool canViewUser(UserModel target, {UserModel? actor}) {
    final user = _resolve(actor);

    if (target.id == user.id) return isSessionValid(actor: user);
    if (target.isSystem) return false;

    return can(Permissions.userView, actor: user);
  }

  static bool canEditUser(UserModel target, {UserModel? actor}) {
    if (target.isSystem) return false;
    return can(Permissions.userEdit, actor: actor);
  }

  static bool canDeleteUser(UserModel target, {UserModel? actor}) {
    if (target.isSystem) return false;
    if (target.id == _resolve(actor).id) return false;

    return can(Permissions.userDelete, actor: actor);
  }

  static bool canViewService(ServiceModel service, {UserModel? actor}) =>
      can(Permissions.serviceView, actor: actor);

  static bool canEditService(ServiceModel service, {UserModel? actor}) =>
      can(Permissions.serviceEdit, actor: actor);

  static bool canDeleteService(ServiceModel service, {UserModel? actor}) =>
      can(Permissions.serviceDelete, actor: actor);

  /// Only Admins (and Super Admins) can view or navigate to saved Activity GPS location.
  static bool canViewActivityGps({UserModel? actor}) =>
      can(Permissions.activityViewGps, actor: actor);

  /// Anyone with activity.view + the normal vehicle data-scope check can see
  /// a running/paused Activity live - this does NOT grant control.
  static bool canViewActivity(
      ActivityModel activity,
      VehicleModel? vehicle, {
        UserModel? actor,
      }) {
    if (!can(Permissions.activityView, actor: actor)) return false;

    final user = _resolve(actor);

    if (activity.startedByUserId == user.id ||
        activity.driverId == user.id ||
        activity.supervisorId == user.id) {
      return true;
    }

    if (vehicle != null) return canViewVehicle(vehicle, actor: user);

    return !isVehicleScoped(actor: user) ||
        user.assignedVehicleIds.contains(activity.vehicleId);
  }

  static bool canEditActivity(
      ActivityModel activity, {
        UserModel? actor,
      }) {
    if (!can(Permissions.activityEdit, actor: actor)) return false;

    return canManageActivity(
      Permissions.activityEdit,
      vehicleId: activity.vehicleId,
      actor: actor,
    );
  }

  /// ONLY the user who originally started this specific Activity may
  /// pause/resume/complete/cancel it - never role, ownership, or who is
  /// currently looking at the screen.
  static bool canControlActivity(ActivityModel activity, {UserModel? actor}) {
    final user = _resolve(actor);

    if (!isSessionValid(actor: user)) return false;
    if (!activity.isLive) return false; // completed/cancelled = frozen
    if (activity.startedByUserId == null) return false;

    return activity.startedByUserId == user.id;
  }

  // ---------------------------------------------------------------------
  // CACHE SCOPE
  // Decides which business tables a session may load at all. Record-level
  // filtering on top of this lives in DataCacheService.
  // ---------------------------------------------------------------------

  static bool canCachePath(String path, {UserModel? actor}) {
    final user = _resolve(actor);

    if (!isSessionValid(actor: user) || user.isGuest) return false;

    switch (path.trim().toLowerCase()) {
      case 'users':
      // Always loaded, but filtered per record: a session without
      // user.view only keeps itself and the people on its vehicles.
        return true;
      case 'vehicles':
        return can(Permissions.vehicleView, actor: user);
      case 'services':
        return can(Permissions.serviceView, actor: user);
      case 'activities':
      case 'customers':
        return can(Permissions.activityView, actor: user);
      case 'activity_locations':
        return canViewActivityGps(actor: user);
      case 'payments':
        return user.isOrganization &&
            can(Permissions.activityView, actor: user);
      case 'expenses':
      case 'expensecategories':
        return can(Permissions.expenseView, actor: user);
      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------
  // PRIVILEGE-ESCALATION GUARDS
  // ---------------------------------------------------------------------

  /// True if [actor] is allowed to set [targetUserId] to [newRoles] under
  /// [newUserType]. Encodes: no self-escalation, no assigning a role the
  /// userType doesn't allow, and only a Super Admin may grant Super Admin.
  static String? validateRoleChange({
    required UserModel actor,
    required String targetUserId,
    required String newUserType,
    required List<String> newRoles,
  }) {
    if (!actor.hasRole(UserRoles.superAdmin) &&
        !actor.hasRole(UserRoles.admin)) {
      return "You don't have permission to perform this action.";
    }

    if (actor.id == targetUserId) {
      return 'You cannot change your own role/user type.';
    }

    final invalid = newRoles
        .where((r) => !UserRoles.isAllowedForUserType(r, newUserType))
        .toList();

    if (invalid.isNotEmpty) {
      return '${invalid.join(', ')} not allowed for $newUserType users.';
    }

    // Only a Super Admin can grant Super Admin.
    if (newRoles.contains(UserRoles.superAdmin) &&
        !actor.hasRole(UserRoles.superAdmin)) {
      return "You don't have permission to perform this action.";
    }

    return null; // valid
  }
}
