import '../../offline_constants.dart';
import '../../offline_models.dart';
import '../sync_adapter.dart';

/// Customers keep their existing uId generator (`generateSequence('C')`).
/// A customer created offline carries a [PendingUid] until sync, when the
/// existing generator supplies the real one.
class CustomerSyncAdapter extends SyncAdapter {
  const CustomerSyncAdapter();

  @override
  String get entityType => SyncEntity.customer;

  @override
  String get remotePath => 'customers';

  @override
  String? get referenceType => ReferenceType.customer;

  @override
  int get dependencyRank => 10;

  @override
  Future<UidResolution?> resolveUid(
    SyncAdapterContext context,
    LocalRecord record, {
    required bool uidClaimed,
  }) async {
    if (!PendingUid.isPending(record.data['uId'])) return null;

    final uId = await context.generateSequence('C');
    return UidResolution(uId: uId, changed: true);
  }
}
