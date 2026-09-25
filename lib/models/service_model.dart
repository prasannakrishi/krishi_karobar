import '../utils/helper/helper_method.dart';

class ServiceModel {
  final String id;
  final String uId;

  String name;
  String description;
  int rate;
  String unit;
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
    this.isActive = true,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      id: toStringValue(map['id'] ?? map['guid']),
      uId: toStringValue(map['uId'] ?? map['uid']),
      name: toStringValue(map['name']),
      description: toStringValue(map['description']),
      rate: toInt(map['rate']),
      unit: toStringValue(map['unit']),
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
      isActive: true,
      createdAt: DateTime.now(),
    );
  }
}
