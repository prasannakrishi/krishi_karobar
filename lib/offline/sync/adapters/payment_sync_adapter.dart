import '../../offline_constants.dart';
import '../../offline_models.dart';
import '../sync_adapter.dart';

/// Syncs immutable payment receipts after their customer and allocated
/// activities exist remotely. Activity balance updates must be queued as
/// activity updates by the payment workflow before this adapter is production-ready.
class PaymentSyncAdapter extends SyncAdapter {
  const PaymentSyncAdapter();

  @override
  String get entityType => SyncEntity.payment;

  @override
  String get remotePath => 'payments';

  @override
  String? get referenceType => ReferenceType.payment;

  @override
  int get dependencyRank => 40;

  @override
  List<SyncParentRef> parentsOf(LocalRecord record) {
    final refs = <SyncParentRef>[];
    final customerId = record.data['customerId']?.toString().trim() ?? '';
    if (customerId.isNotEmpty) {
      refs.add(SyncParentRef(SyncEntity.customer, customerId));
    }
    final raw = record.data['allocations'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final activityId = item['activityId']?.toString().trim() ?? '';
          if (activityId.isNotEmpty) {
            refs.add(SyncParentRef(SyncEntity.activity, activityId));
          }
        }
      }
    }
    return refs;
  }
}
