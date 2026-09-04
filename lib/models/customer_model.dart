import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:uuid/uuid.dart';

class CustomerModel {
  final String guid;
  String name;
  String phone;
  String address;
  DateTime createdAt;
  String? createdBy; // GUID String

  CustomerModel({
    required this.guid,
    required this.name,
    required this.phone,
    required this.address,
    required this.createdAt,
    this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'guid': guid,
      'name': name,
      'phone': phone,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return CustomerModel(
      guid: (map['guid'] ?? const Uuid().v4()).toString(),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      createdAt: parseDate(map['createdAt']),
      createdBy: map['createdBy']?.toString(),
    );
  }

  factory CustomerModel.empty() {
    return CustomerModel(
      guid: Uuid().v4(),
      name: '',
      phone: '',
      address: '',
      createdAt: DateTime.now(),
      createdBy: LoginController.loginUser.guid,
    );
  }
}
