import 'package:uuid/uuid.dart';

class ServiceModel {
  final String guid;
  final String name;
  final int rate;
  final String unit;
  String createdBy; // GUID String

  ServiceModel({
    required this.guid,
    required this.name,
    required this.rate,
    required this.unit,
    required this.createdBy,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      guid: (map['guid'] ?? map['id'] ?? '').toString(),
      name: map['name'] ?? '',
      rate: (map['rate'] is int)
          ? map['rate']
          : int.tryParse(map['rate']?.toString() ?? '0') ?? 0,
      unit: map['unit'] ?? '',
      createdBy: (map['createdBy'] ?? '').toString(),
    );
  }

  factory ServiceModel.empty([String name = '']) {
    return ServiceModel(
      guid: const Uuid().v4(),
      name: name,
      rate: 0,
      unit: '',
      createdBy: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'guid': guid,
      'name': name,
      'rate': rate,
      'unit': unit,
      'createdBy': createdBy,
    };
  }
}
