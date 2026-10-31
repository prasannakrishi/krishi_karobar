import '../offline_constants.dart';

/// Lookup fields copied from a record's data to top-level keys of the
/// stored map. Sembast has no secondary indexes, so list/filter queries
/// (by vehicle, customer, status, entity) run on these flat fields with a
/// `Finder`; the full record stays in `data`.
class RecordIndexFields {
  const RecordIndexFields({
    this.vehicleId = '',
    this.customerId = '',
    this.status = '',
  });

  final String vehicleId;
  final String customerId;
  final String status;
}

class LocalRecordIndex {
  LocalRecordIndex._();

  static RecordIndexFields derive({
    required String entityType,
    required String recordId,
    required Map<String, Object?> data,
    String? scopeVehicleId,
  }) {
    String text(Object? value) => value?.toString().trim() ?? '';

    final canonical = SyncEntity.canonical(entityType);

    var vehicleId = text(data['vehicleId']);
    if (vehicleId.isEmpty && scopeVehicleId != null) {
      vehicleId = scopeVehicleId;
    }

    final customerId =
        canonical == SyncEntity.customer ? recordId : text(data['customerId']);

    return RecordIndexFields(
      vehicleId: vehicleId,
      customerId: customerId,
      status: text(data['status']),
    );
  }
}
