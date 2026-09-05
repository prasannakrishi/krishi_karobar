import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:krishi_karobar/models/enums.dart';
import 'package:krishi_karobar/utils/helper/helper_method.dart';
import 'package:uuid/uuid.dart';

class ServiceModel {
  final String guid;
  final Service service;
  final String name;
  final String description;

  double rate;
  ServiceUnit unit;
  bool isActive;

  String? imageUrl;

  final DateTime? createdAt;
  DateTime? updatedAt;

  final String createdBy;

  ServiceModel({
    required this.guid,
    required this.service,
    required this.name,
    required this.description,
    required this.rate,
    required this.unit,
    this.isActive = true,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      guid: toStringValue(map['guid'] ?? map['id']),
      service: enumFromString(Service.values, map['service']?.toString()),
      name: toStringValue(map['name']),
      description: toStringValue(map['description']),
      rate: toDouble(map['rate']),
      unit: enumFromString(ServiceUnit.values, map['unit']?.toString()),
      isActive: toBool(map['isActive'], defaultValue: true),
      imageUrl: map['imageUrl']?.toString(),
      createdAt: toDateTime(map['createdAt']),
      updatedAt: toDateTime(map['updatedAt']),
      createdBy: toStringValue(map['createdBy']),
    );
  }

  factory ServiceModel.empty([String name = '']) {
    return ServiceModel(
      guid: const Uuid().v4(),
      service: Service.rotavator,
      name: name,
      description: '',
      rate: 0.0,
      unit: ServiceUnit.hour,
      isActive: true,
      imageUrl: null,
      createdAt: DateTime.now(),
      updatedAt: null,
      createdBy: LoginController.loginUser.guid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'guid': guid,
      'service': service.name,
      'name': name,
      'description': description,
      'rate': rate,
      'unit': unit.name,
      'isActive': isActive,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy,
    };
  }
}