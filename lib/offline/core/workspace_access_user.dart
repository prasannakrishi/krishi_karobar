import '../../models/user_model.dart';
import '../../services/authorization_service.dart';
import 'workspace_access.dart';

/// Builds the offline access record for a signed-in user.
///
/// [ownedVehicleIds]: vehicles whose `ownerId` is this user (Authz lets a
/// vehicle owner use them even when they are not in `assignedVehicleIds`).
/// Kept apart from `WorkspaceAccess` so the storage layer does not depend
/// on the user model or the authorization service.
WorkspaceAccess workspaceAccessFor(
  UserModel user, {
  Iterable<String> ownedVehicleIds = const [],
}) {
  return WorkspaceAccess(
    userType: user.userType,
    roles: List<String>.from(user.roles),
    vehicleIds: {...user.assignedVehicleIds, ...ownedVehicleIds}.toList(),
    allVehicles: !Authz.isVehicleScoped(actor: user),
  );
}
