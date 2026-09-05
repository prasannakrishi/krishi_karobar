import '../utils/helper/helper_method.dart';

class CustomerModel {
  final String id;
  final String uId;

  String name;
  String phone;
  String address;

  final DateTime createdAt;
  String? createdBy;

  DateTime? updatedAt;
  String? updatedBy;

  CustomerModel({
    required this.id,
    required this.uId,
    required this.name,
    required this.phone,
    required this.address,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: toStringValue(map['id'] ?? map['guid']),
      uId: toStringValue(map['uId'] ?? map['uid']),
      name: toStringValue(map['name']),
      phone: toStringValue(map['phone']),
      address: toStringValue(map['address']),
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
      'phone': phone,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  factory CustomerModel.empty() {
    return CustomerModel(
      id: '',
      uId: '',
      name: '',
      phone: '',
      address: '',
      createdAt: DateTime.now(),
    );
  }
}
