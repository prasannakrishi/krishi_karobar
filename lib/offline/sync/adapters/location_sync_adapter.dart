import '../../offline_constants.dart';
import '../../offline_models.dart';
import '../sync_adapter.dart';

/// GPS location documents (`activity_locations/{id}`,
/// `expense_locations/{id}`). They are written with merge semantics, as the
/// app already does, and can only be read back by admins - so a successful
/// acknowledged write is their confirmation.
class LocationSyncAdapter extends SyncAdapter {
  const LocationSyncAdapter._({
    required this.entityType,
    required this.remotePath,
    required this.parentEntityType,
    required this.dependencyRank,
  });

  const LocationSyncAdapter.activity()
      : this._(
          entityType: SyncEntity.activityLocation,
          remotePath: 'activity_locations',
          parentEntityType: SyncEntity.activity,
          dependencyRank: 25,
        );

  const LocationSyncAdapter.expense()
      : this._(
          entityType: SyncEntity.expenseLocation,
          remotePath: 'expense_locations',
          parentEntityType: SyncEntity.expense,
          dependencyRank: 35,
        );

  @override
  final String entityType;

  @override
  final String remotePath;

  @override
  final int dependencyRank;

  /// The location document shares its id with its parent record.
  final String parentEntityType;

  @override
  String? get referenceType => null;

  @override
  SyncWriteMode get writeMode => SyncWriteMode.merge;

  @override
  SyncVerification get verification => SyncVerification.writeAcknowledged;

  @override
  List<String> get immutableFields => const [];

  @override
  List<SyncParentRef> parentsOf(LocalRecord record) {
    return [SyncParentRef(parentEntityType, record.recordId)];
  }

  @override
  Map<String, Object?> buildCreatePayload(LocalRecord record) {
    final payload = deepCopyMap(record.data);
    payload['id'] = record.recordId;
    return payload;
  }

  @override
  Map<String, Object?> buildUpdatePatch(LocalRecord record) {
    return buildCreatePayload(record);
  }
}
