import '../../utils/constants/environment_config.dart';
import '../offline_exceptions.dart';

/// Identifies the offline workspace: ONE per environment and owner.
///
/// Vehicle is a record-level attribute (each record carries its own
/// `vehicleId`) and access to it is enforced through the owner's assigned
/// vehicles (`WorkspaceAccess`), so switching the selected vehicle never
/// opens, closes or blocks a workspace.
///
/// Every repository call requires a scope, so a query can never return
/// another user's offline data.
class WorkspaceScope {
  const WorkspaceScope({
    required this.environment,
    required this.ownerUserId,
    required this.authUid,
    this.vehicleId = '',
  });

  /// Scope for the running build (dev or prod).
  ///
  /// [vehicleId] is accepted so existing callers keep compiling, but it is
  /// NOT part of the workspace identity: a missing value or the retired
  /// `'default'` placeholder can no longer send data to a different
  /// workspace.
  factory WorkspaceScope.forCurrentEnvironment({
    required String ownerUserId,
    required String authUid,
    String vehicleId = '',
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
  final String environment;

  /// The vehicle the caller had selected. Informational only.
  final String vehicleId;

  /// `environment|owner`. Also the reference-snapshot namespace.
  String get workspaceId => idFor(environment, ownerUserId);

  static String idFor(String environment, String ownerUserId) =>
      '$environment|$ownerUserId';

  /// Owner part of a workspace id (also of the legacy
  /// `environment|owner|vehicle` shape), or `null` when malformed.
  static String? ownerOf(String workspaceId) {
    final parts = workspaceId.split('|');
    return parts.length >= 2 && parts[1].isNotEmpty ? parts[1] : null;
  }

  /// Environment part of a workspace id, or `null` when malformed.
  static String? environmentOf(String workspaceId) {
    final parts = workspaceId.split('|');
    return parts.length >= 2 && parts[0].isNotEmpty ? parts[0] : null;
  }

  /// Throws [OfflineScopeException] when environment, owner or auth uid is
  /// blank, padded, or contains the `|` separator - a blank part would
  /// silently merge unrelated data.
  void validate() {
    final fields = {
      'environment': environment,
      'ownerUserId': ownerUserId,
      'authUid': authUid,
    };

    for (final entry in fields.entries) {
      final value = entry.value;
      if (value.trim().isEmpty) {
        throw OfflineScopeException.invalid(details: '${entry.key} is empty');
      }
      if (value.trim() != value || value.contains('|')) {
        throw OfflineScopeException.invalid(
          details: '${entry.key} has surrounding spaces or "|"',
        );
      }
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
