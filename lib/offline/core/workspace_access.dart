import '../../models/user_types.dart';
import 'offline_entity_roles.dart';

/// Who the workspace belongs to and what it may touch: the owner's user
/// type (organization / external / guest), roles and vehicle access. Stored
/// with the workspace so the repository can refuse local writes the
/// server-side rules would reject anyway, and so the same policy is applied
/// when a workspace is restored after a restart. The UI and Firebase rules
/// stay authoritative; this only keeps a disallowed record from entering,
/// or being read out of, the local store.
class WorkspaceAccess {
  const WorkspaceAccess({
    required this.userType,
    required this.roles,
    this.vehicleIds = const [],
    this.allVehicles = false,
  });

  factory WorkspaceAccess.fromMap(Map<String, Object?> map) {
    List<String> strings(Object? value) => value is List
        ? [for (final item in value) item.toString()]
        : <String>[];

    return WorkspaceAccess(
      userType: map['userType']?.toString() ?? UserTypes.guest,
      roles: strings(map['roles']),
      vehicleIds: strings(map['vehicleIds']),
      allVehicles: map['allVehicles'] == true,
    );
  }

  final String userType;
  final List<String> roles;

  /// Assigned or owned vehicles.
  final List<String> vehicleIds;

  /// Admin-level or non-vehicle-scoped users see every vehicle.
  final bool allVehicles;

  bool get isGuest => userType == UserTypes.guest;

  /// May this user create or change local records of [entityType]? Mirrors
  /// the Firebase write rules per entity; a guest or role-less user never
  /// may.
  bool canWrite(String entityType) {
    if (isGuest || roles.isEmpty) return false;
    final allowed = OfflineEntityRoles.writeRoles(entityType);
    return roles.any(allowed.contains);
  }

  /// A record without a vehicle (customers, payments) is not vehicle
  /// scoped; a record with one needs that vehicle to be allowed.
  bool canUseVehicle(String vehicleId) {
    if (vehicleId.isEmpty) return true;
    return allVehicles || vehicleIds.contains(vehicleId);
  }

  Map<String, Object?> toMap() => {
        'userType': userType,
        'roles': List<String>.from(roles),
        'vehicleIds': List<String>.from(vehicleIds),
        'allVehicles': allVehicles,
      };
}
