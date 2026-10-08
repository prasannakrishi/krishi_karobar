import '../../offline_constants.dart';
import '../../offline_exceptions.dart';
import '../../offline_models.dart';
import '../sync_adapter.dart';

/// Activities keep their existing uId generator (`generateActivityUid`).
/// An activity created offline carries a [PendingUid] until sync. The
/// existing generator then runs with the activity's service name and
/// vehicle uId, so the period in the final uId reflects the sync month
/// (existing behavior is unchanged).
class ActivitySyncAdapter extends SyncAdapter {
  const ActivitySyncAdapter();

  @override
  String get entityType => SyncEntity.activity;

  @override
  String get remotePath => 'activities';

  @override
  String? get referenceType => ReferenceType.activity;

  @override
  int get dependencyRank => 20;

  @override
  List<SyncParentRef> parentsOf(LocalRecord record) {
    final customerId = record.data['customerId']?.toString().trim() ?? '';

    return [
      if (customerId.isNotEmpty) SyncParentRef(SyncEntity.customer, customerId),
    ];
  }

  @override
  Future<UidResolution?> resolveUid(
    SyncAdapterContext context,
    LocalRecord record, {
    required bool uidClaimed,
  }) async {
    if (!PendingUid.isPending(record.data['uId'])) return null;

    final serviceId = record.data['serviceId']?.toString() ?? '';
    final vehicleId = record.data['vehicleId']?.toString() ?? '';

    final service = await context.reference(ReferenceType.service, serviceId);
    final vehicle = await context.reference(ReferenceType.vehicle, vehicleId);

    final serviceName = service?['name']?.toString().trim() ?? '';
    final vehicleUId = vehicle?['uId']?.toString().trim() ?? '';

    if (serviceName.isEmpty) {
      throw SyncPreparationException.missingReference(
        type: 'service',
        id: serviceId,
      );
    }

    if (vehicleUId.isEmpty) {
      throw SyncPreparationException.missingReference(
        type: 'vehicle',
        id: vehicleId,
      );
    }

    final uId = await context.generateActivityUid(
      serviceType: serviceName,
      vehicleUId: vehicleUId,
    );

    return UidResolution(uId: uId, changed: true);
  }
}
