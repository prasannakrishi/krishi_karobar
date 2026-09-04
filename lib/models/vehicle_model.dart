import 'package:uuid/uuid.dart';

class VehicleModel {
  final String guid;
  final String name;
  final String number;
  final String vehicleType;
  final String? model;
  final DateTime createdAt;

  String ownerId; // GUID String
  String? driverId; // GUID String
  String? supervisorId; // GUID String
  String createdBy; // GUID String

  VehicleModel({
    required this.guid,
    required this.name,
    required this.number,
    required this.vehicleType,
    this.model,
    required this.createdAt,
    required this.ownerId,
    this.driverId,
    this.supervisorId,
    required this.createdBy,
  });

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return VehicleModel(
      guid: (map['guid'] ?? map['id'] ?? '').toString(),
      name: map['name'] ?? '',
      number: map['number'] ?? '',
      vehicleType: map['vehicleType'] ?? '',
      model: map['model']?.toString(),
      createdAt: parseDate(map['createdAt']),
      ownerId: (map['ownerId'] ?? '').toString(),
      driverId: map['driverId']?.toString(),
      supervisorId: map['supervisorId']?.toString(),
      createdBy: (map['createdBy'] ?? '').toString(),
    );
  }

  factory VehicleModel.empty() {
    return VehicleModel(
      guid: '',
      name: '',
      number: '',
      vehicleType: '',
      model: null,
      createdAt: DateTime.now(),
      ownerId: '',
      driverId: null,
      supervisorId: null,
      createdBy: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'guid': guid,
      'name': name,
      'number': number,
      'vehicleType': vehicleType,
      'model': model,
      'createdAt': createdAt.toIso8601String(),
      'ownerId': ownerId,
      'driverId': driverId,
      'supervisorId': supervisorId,
      'createdBy': createdBy,
    };
  }
}
