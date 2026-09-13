import '../features/authentication/controllers/login_controllers.dart';
import '../models/models.dart';

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

  static const activityView = 'activity.view';
  static const activityCreate = 'activity.create';
  static const activityEdit = 'activity.edit';
  static const activityStart = 'activity.start';
  static const activityComplete = 'activity.complete';
  static const activityCancel = 'activity.cancel';

  static const settingsView = 'settings.view';
  static const settingsEdit = 'settings.edit';

  static const auditView = 'audit.view';
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
      Permissions.activityView, Permissions.activityCreate,
      Permissions.activityEdit, Permissions.activityStart,
      Permissions.activityComplete, Permissions.activityCancel,
      Permissions.settingsView, Permissions.settingsEdit,
      Permissions.auditView,
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
      Permissions.activityView, Permissions.activityCreate,
      Permissions.activityEdit, Permissions.activityStart,
      Permissions.activityComplete, Permissions.activityCancel,
      Permissions.settingsView, Permissions.settingsEdit,
    },
    UserRoles.manager: {
      Permissions.userView,
      Permissions.vehicleView, Permissions.vehicleEdit,
      Permissions.serviceView, Permissions.serviceCreate,
      Permissions.serviceEdit,
      Permissions.activityView, Permissions.activityCreate,
      Permissions.activityEdit, Permissions.activityStart,
      Permissions.activityComplete, Permissions.activityCancel,
      Permissions.settingsView,
    },
    UserRoles.accountant: {
      Permissions.userView,
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView,
      // finance.* intentionally omitted - no finance module yet.
    },
    UserRoles.supervisor: {
      Permissions.userView,
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView, Permissions.activityStart,
      Permissions.activityEdit, Permissions.activityComplete,
    },
    UserRoles.driver: {
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView, Permissions.activityStart,
      Permissions.activityComplete,
    },
    UserRoles.vehicleOwner: {
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView,
    },
    UserRoles.viewer: {
      Permissions.userView,
      Permissions.vehicleView,
      Permissions.serviceView,
      Permissions.activityView,
      Permissions.settingsView,
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
class Authz {
  Authz._();

  static UserModel get _user => LoginController.loginUser;

  static bool get isAuthenticated => _user.id.isNotEmpty;

  static bool get isActive => _user.status.trim().toLowerCase() == 'active';

  /// True if the current session is allowed to do anything at all.
  static bool get isSessionValid => isAuthenticated && isActive;

  static bool hasUserType(String userType) => _user.userType == userType;

  static bool hasRole(String role) => _user.hasRole(role);

  static bool hasAnyRole(Iterable<String> roles) =>
      roles.any(_user.hasRole);

  static Set<String> get _permissions {
    if (!isSessionValid || _user.isGuest) return const {};
    return _RolePermissions.forRoles(_user.roles);
  }

  /// Core check: authentication + active status + permission grant.
  /// Data-scope/business-rule checks are additive on top of this -
  /// see [canViewVehicle] / [canManageActivity] for examples.
  static bool can(String permission) {
    if (!isSessionValid) return false;
    return _permissions.contains(permission);
  }

  static bool canAny(List<String> permissions) => permissions.any(can);

  static bool canAll(List<String> permissions) => permissions.every(can);

  static bool canAccessModule(String modulePrefix) {
    if (!isSessionValid) return false;
    return _permissions.any((p) => p.startsWith('$modulePrefix.'));
  }

  // ---------------------------------------------------------------------
  // DATA SCOPE HELPERS (spec section 8)
  // Permission alone is not enough - these add the "is this MY record"
  // check on top of the raw permission.
  // ---------------------------------------------------------------------

  /// Vehicle Owners/Drivers may only view vehicles assigned to them;
  /// everyone else with vehicle.view sees every vehicle.
  static bool canViewVehicle(VehicleModel vehicle) {
    if (!can(Permissions.vehicleView)) return false;
    if (_user.hasAllVehicleAccess) return true;
    if (!_user.hasRole(UserRoles.driver) &&
        !_user.hasRole(UserRoles.vehicleOwner)) {
      return true;
    }
    return vehicle.ownerId == _user.id ||
        _user.assignedVehicleIds.contains(vehicle.id);
  }

  /// Drivers/Vehicle Owners may only act on activities tied to a vehicle
  /// they're scoped to; everyone else with the base permission can proceed.
  static bool canManageActivity(String permission, {String? vehicleId}) {
    if (!can(permission)) return false;
    if (vehicleId == null) return true;
    if (_user.hasAllVehicleAccess) return true;
    if (!_user.hasRole(UserRoles.driver) &&
        !_user.hasRole(UserRoles.vehicleOwner)) {
      return true;
    }
    return _user.assignedVehicleIds.contains(vehicleId);
  }

  // ---------------------------------------------------------------------
  // PRIVILEGE-ESCALATION GUARDS (spec sections 13/14/28)
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
