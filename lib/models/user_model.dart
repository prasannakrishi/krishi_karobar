import 'package:uuid/uuid.dart';

class UserModel {
  static const String systemGuid = '00000000-0000-0000-0000-000000000000';

  final String guid;
  final String uid;
  String name;
  String? email;
  String phone;
  String address;
  String usertype;
  String roll;
  String password;
  bool isCustomer;
  DateTime? updatedAt;
  String? updatedBy; // GUID String
  final DateTime createdAt;
  String? createdBy; // GUID String

  UserModel({
    required this.guid,
    required this.uid,
    required this.name,
    this.email,
    required this.phone,
    required this.address,
    required this.usertype,
    required this.roll,
    required this.password,
    required this.isCustomer,
    this.updatedAt,
    this.updatedBy,
    required this.createdAt,
    this.createdBy,
  });

  static UserModel _systemUser = UserModel(
    guid: systemGuid,
    uid: 'SU-01',
    name: 'Prasanna Aadhunik Krishi Kendra',
    email: 'prasannakrishi@hotmail.com',
    phone: '9858028096',
    address: 'Ghorahi-15, Dang',
    usertype: 'System User',
    roll: 'Admin',
    password: '',
    isCustomer: false,
    updatedAt: null,
    updatedBy: null,
    createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
    createdBy: null,
  );

  static UserModel get systemUser => _systemUser;

  static void setSystemUser(UserModel user) {
    if (user.guid != systemGuid) {
      throw Exception('Invalid System User GUID');
    }
    _systemUser = user;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      guid: (map['guid'] ?? map['id'] ?? '').toString(),
      uid: (map['uid'] ?? '').toString(),
      name: map['name'] ?? '',
      email: map['email'],
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      usertype: map['usertype'] ?? '',
      roll: map['roll'] ?? '',
      password: map['password'] ?? '',
      isCustomer: map['isCustomer'] ?? true,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
      updatedBy: map['updatedBy']?.toString(),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      createdBy: map['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'guid': guid,
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'usertype': usertype,
      'roll': roll,
      'password': password,
      'isCustomer': isCustomer,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory UserModel.empty() {
    return UserModel(
      guid: '',
      uid: '',
      name: '',
      email: null,
      phone: '',
      address: '',
      usertype: '',
      roll: '',
      password: '',
      isCustomer: false,
      updatedAt: null,
      updatedBy: null,
      createdAt: DateTime.now(),
      createdBy: null,
    );
  }
}
