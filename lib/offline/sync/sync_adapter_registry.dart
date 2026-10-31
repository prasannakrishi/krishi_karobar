import 'adapters/activity_sync_adapter.dart';
import 'adapters/customer_sync_adapter.dart';
import 'adapters/expense_sync_adapter.dart';
import 'adapters/location_sync_adapter.dart';
import 'adapters/payment_sync_adapter.dart';
import 'sync_adapter.dart';

/// Looks up the adapter for an entity type. A `user` (or any later)
/// adapter is added by registering it here; storage and queue need no
/// change.
class SyncAdapterRegistry {
  SyncAdapterRegistry(Iterable<SyncAdapter> adapters)
      : _adapters = {for (final a in adapters) a.entityType: a};

  factory SyncAdapterRegistry.standard() {
    return SyncAdapterRegistry(const [
      CustomerSyncAdapter(),
      ActivitySyncAdapter(),
      LocationSyncAdapter.activity(),
      ExpenseSyncAdapter(),
      LocationSyncAdapter.expense(),
      PaymentSyncAdapter(),
    ]);
  }

  final Map<String, SyncAdapter> _adapters;

  bool supports(String entityType) => _adapters.containsKey(entityType);

  SyncAdapter? tryAdapterFor(String entityType) => _adapters[entityType];

  /// Throws [StateError] for an unregistered type: the engine must not
  /// silently skip data it cannot sync.
  SyncAdapter adapterFor(String entityType) {
    final adapter = _adapters[entityType];
    if (adapter == null) {
      throw StateError('No sync adapter is registered for "$entityType".');
    }
    return adapter;
  }

  /// Adapters ordered parent-first.
  List<SyncAdapter> get ordered {
    final list = _adapters.values.toList()
      ..sort((a, b) => a.dependencyRank.compareTo(b.dependencyRank));
    return list;
  }

  List<String> get entityTypes => _adapters.keys.toList();

}
