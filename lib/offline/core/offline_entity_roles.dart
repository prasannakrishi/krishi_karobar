import '../offline_constants.dart';

/// Roles allowed to write each offline entity, copied from
/// `firebase_rtdb.rules.json` (customers, activities, payments, expenses and
/// their location documents). The server rules stay authoritative; this is
/// the same list applied before a record is stored locally. Other entity
/// types (for example `user`) are admin-only here because their offline
/// editing is not allowed.
class OfflineEntityRoles {
  OfflineEntityRoles._();

  static const List<String> _everyone = [
    'super_admin',
    'admin',
    'manager',
    'accountant',
    'supervisor',
    'driver',
  ];

  static const List<String> _operations = [
    'super_admin',
    'admin',
    'manager',
    'supervisor',
    'driver',
  ];

  static const List<String> _adminOnly = ['super_admin', 'admin'];

  static List<String> writeRoles(String entityType) {
    switch (SyncEntity.canonical(entityType)) {
      case SyncEntity.customer:
      case SyncEntity.activity:
      case SyncEntity.payment:
        return _everyone;
      case SyncEntity.expense:
      case SyncEntity.activityLocation:
      case SyncEntity.expenseLocation:
        return _operations;
      default:
        return _adminOnly;
    }
  }
}
