import '../utils/helper/helper_method.dart';

class VehicleModel {
  final String id;
  final String uId;

  String name;
  String number;
  String vehicleType;
  String? model;

  /// ServiceModel.id values supported by this vehicle.
  List<String> supportServiceIds;

  /// CustomerModel.id of the vehicle owner.
  String ownerId;

  /// UserModel.id of the assigned driver.
  String? driverId;

  /// UserModel.id of the assigned supervisor.
  String? supervisorId;

  /// Current vehicle status.
  String status;

  /// Whether this vehicle can currently be used for booking.
  bool isActive;

  /// Optional vehicle-specific notes.
  String? notes;

  final DateTime createdAt;
  String? createdBy;

  DateTime? updatedAt;
  String? updatedBy;

  VehicleModel({
    required this.id,
    required this.uId,
    required this.name,
    required this.number,
    required this.vehicleType,
    this.model,
    this.supportServiceIds = const [],
    required this.ownerId,
    this.driverId,
    this.supervisorId,
    this.status = 'available',
    this.isActive = true,
    this.notes,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    final rawServiceIds = map['supportServiceIds'];

    final serviceIds = rawServiceIds is List
        ? rawServiceIds
              .map((item) => item.toString())
              .where((id) => id.isNotEmpty)
              .toList()
        : <String>[];

    return VehicleModel(
      id: toStringValue(map['id'] ?? map['guid']),
      uId: toStringValue(map['uId'] ?? map['uid']),
      name: toStringValue(map['name']),
      number: toStringValue(map['number']),
      vehicleType: toStringValue(map['vehicleType']),
      model: map['model']?.toString(),
      supportServiceIds: serviceIds,
      ownerId: toStringValue(map['ownerId']),
      driverId: map['driverId']?.toString(),
      supervisorId: map['supervisorId']?.toString(),
      status: toStringValue(map['status'], defaultValue: 'available'),
      isActive: toBool(map['isActive'], defaultValue: true),
      notes: map['notes']?.toString(),
      createdAt: toDateTime(map['createdAt']) ?? DateTime.now(),
      createdBy: map['createdBy']?.toString(),
      updatedAt: toDateTime(map['updatedAt']),
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uId': uId,
      'name': name,
      'number': number,
      'vehicleType': vehicleType,
      'model': model,
      'supportServiceIds': supportServiceIds,
      'ownerId': ownerId,
      'driverId': driverId,
      'supervisorId': supervisorId,
      'status': status,
      'isActive': isActive,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  factory VehicleModel.empty() {
    return VehicleModel(
      id: '',
      uId: '',
      name: '',
      number: '',
      vehicleType: '',
      model: null,
      supportServiceIds: [],
      ownerId: '',
      driverId: null,
      supervisorId: null,
      status: 'available',
      isActive: true,
      notes: null,
      createdAt: DateTime.now(),
    );
  }
}
