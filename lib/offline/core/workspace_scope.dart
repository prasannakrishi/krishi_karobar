import '../../utils/constants/environment_config.dart';

/// Identifies one offline workspace: environment + owner + vehicle.
///
/// Every repository call requires a scope, so a query can never return
/// another user's or another vehicle's offline data.
class WorkspaceScope {
  const WorkspaceScope({
    required this.environment,
    required this.ownerUserId,
    required this.authUid,
    required this.vehicleId,
  });

  /// Scope for the running build (dev or prod).
  factory WorkspaceScope.forCurrentEnvironment({
    required String ownerUserId,
    required String authUid,
    required String vehicleId,
  }) {
    return WorkspaceScope(
      environment: EnvironmentConfig.currentEnvironment.name,
      ownerUserId: ownerUserId,
      authUid: authUid,
      vehicleId: vehicleId,
    );
  }

  /// Business `users.id` of the owner (never the Firebase Auth uid).
  final String ownerUserId;

  /// Firebase Auth uid used to authorize writes during sync.
  final String authUid;
  final String vehicleId;
  final String environment;

  String get workspaceId => '$environment|$ownerUserId|$vehicleId';

  /// Throws [ArgumentError] when a field is blank - a blank owner or
  /// vehicle would silently merge unrelated data.
  void validate() {
    if (environment.trim().isEmpty ||
        ownerUserId.trim().isEmpty ||
        authUid.trim().isEmpty ||
        vehicleId.trim().isEmpty) {
      throw ArgumentError(
        'WorkspaceScope requires environment, ownerUserId, authUid and '
        'vehicleId.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WorkspaceScope &&
      other.workspaceId == workspaceId &&
      other.authUid == authUid;

  @override
  int get hashCode => Object.hash(workspaceId, authUid);

  @override
  String toString() => 'WorkspaceScope($workspaceId)';
}
