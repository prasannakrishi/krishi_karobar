import 'user_types.dart';

class UserRoles {
  static const String superAdmin = 'super_admin';
  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String accountant = 'accountant';
  static const String driver = 'driver';
  static const String supervisor = 'supervisor';
  static const String viewer = 'viewer';
  static const String vehicleOwner = 'vehicle_owner';

  static const List<String> values = [
    superAdmin,
    admin,
    manager,
    accountant,
    driver,
    supervisor,
    viewer,
    vehicleOwner,
  ];

  static bool isValid(String value) {
    return values.contains(value);
  }

  /// Roles an ORGANIZATION user is allowed to hold.
  static const List<String> organizationRoles = [
    superAdmin,
    admin,
    manager,
    accountant,
    supervisor,
    driver,
    viewer,
  ];

  /// Roles an EXTERNAL user is allowed to hold.
  /// External users must never hold superAdmin/admin/manager/accountant.
  static const List<String> externalRoles = [
    supervisor,
    driver,
    vehicleOwner,
    viewer,
  ];

  /// GUEST users never hold a role.
  static const List<String> guestRoles = [];

  static List<String> rolesFor(String userType) {
    switch (userType) {
      case UserTypes.organization:
      case UserTypes.system:
        return organizationRoles;
      case UserTypes.external:
        return externalRoles;
      case UserTypes.guest:
      default:
        return guestRoles;
    }
  }

  /// True if [role] is a legal role for [userType] (spec section 6 matrix).
  static bool isAllowedForUserType(String role, String userType) {
    return rolesFor(userType).contains(role);
  }

  /// Filters out any role not legal for [userType] - last line of defense
  /// against invalid userType+role combinations (e.g. External + Admin).
  static List<String> sanitizeForUserType(
      List<String> roles,
      String userType,
      ) {
    final allowed = rolesFor(userType);
    return roles.where(allowed.contains).toSet().toList();
  }
}
