import '../utils/helper/helper_method.dart';

class ServiceModel {
  final String id;
  final String uId;

  String name;
  String description;
  int rate;
  String unit;
  String? _vehicleType;

  String get vehicleType => _vehicleType ?? 'All';
  set vehicleType(String? value) =>
      _vehicleType = (value == null || value.trim().isEmpty) ? 'All' : value.trim();

  bool isActive;

  final DateTime createdAt;
  String? createdBy;

  DateTime? updatedAt;
  String? updatedBy;

  ServiceModel({
    required this.id,
    required this.uId,
    required this.name,
    required this.description,
    required this.rate,
    required this.unit,
    String? vehicleType,
    this.isActive = true,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  }) : _vehicleType = (vehicleType == null || vehicleType.trim().isEmpty) ? 'All' : vehicleType.trim();

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    final rawVType = map['vehicleType']?.toString().trim();
    final rawUnit = map['unit']?.toString().trim();

    return ServiceModel(
      id: toStringValue(map['id'] ?? map['guid']),
      uId: toStringValue(map['uId'] ?? map['uid']),
      name: toStringValue(map['name']),
      description: toStringValue(map['description']),
      rate: toInt(map['rate']),
      unit: (rawUnit == null || rawUnit.isEmpty) ? 'hour' : rawUnit,
      vehicleType: (rawVType == null || rawVType.isEmpty) ? 'All' : rawVType,
      isActive: toBool(map['isActive'], defaultValue: true),
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
      'description': description,
      'rate': rate,
      'unit': unit,
      'vehicleType': vehicleType,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  factory ServiceModel.empty() {
    return ServiceModel(
      id: '',
      uId: '',
      name: '',
      description: '',
      rate: 0,
      unit: 'hour',
      vehicleType: 'All',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }
}
