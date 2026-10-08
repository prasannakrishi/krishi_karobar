import '../../offline_constants.dart';
import '../../offline_exceptions.dart';
import '../../offline_models.dart';
import '../../uid/expense_uid_format.dart';
import '../sync_adapter.dart';

/// Expenses use the new vehicle-wise Nepali-year uId (`EV01-30001`).
///
/// A provisional uId in that format is claimed on the server at sync: free
/// -> kept, taken -> next free number. Only `uId` changes. Expenses saved
/// in the older format (`E6-0001`) are left alone.
class ExpenseSyncAdapter extends SyncAdapter {
  const ExpenseSyncAdapter();

  @override
  String get entityType => SyncEntity.expense;

  @override
  String get remotePath => 'expenses';

  @override
  String? get referenceType => ReferenceType.expense;

  @override
  int get dependencyRank => 30;

  @override
  List<SyncParentRef> parentsOf(LocalRecord record) {
    final activityId = record.data['activityId']?.toString().trim() ?? '';

    return [
      if (activityId.isNotEmpty) SyncParentRef(SyncEntity.activity, activityId),
    ];
  }

  @override
  Future<UidResolution?> resolveUid(
    SyncAdapterContext context,
    LocalRecord record, {
    required bool uidClaimed,
  }) async {
    if (uidClaimed) return null;

    final current = record.data['uId']?.toString() ?? '';
    final parts = ExpenseUidFormat.tryParse(current);
    if (parts == null) return null;

    // The vehicle code is taken from the provisional uId itself (decided at
    // allocation); the year comes from the record's own createdAt.
    final createdAt = DateTime.tryParse(
      record.data['createdAt']?.toString() ?? '',
    );

    if (createdAt == null) {
      throw SyncPreparationException(
        'The expense ${record.recordId} has no valid creation time, so its '
        'uId cannot be settled.',
        code: 'sync-created-at-missing',
        details: record.recordId,
      );
    }

    final result = await context.expenseUid.reconcile(
      provisionalUId: current,
      vehicleCode: parts.vehicleCode,
      createdAt: createdAt,
    );

    return UidResolution(uId: result.uId, changed: result.changed);
  }
}
