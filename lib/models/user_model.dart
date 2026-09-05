import '../utils/helper/helper_method.dart';

class UserModel {
  static const String systemId = '00000000-0000-0000-0000-000000000000';

  final String id;
  final String uId;
  String fullname;
  String? email;
  String phone;
  String? permanentAddress;
  String? temporaryAddress;
  List<String> roles;
  String? userType;
  String status;
  final DateTime createdAt;
  String? createdBy;
  DateTime? updatedAt;
  String? updatedBy;

  UserModel({
    required this.id,
    required this.uId,
    required this.fullname,
    this.email,
    required this.phone,
    this.permanentAddress,
    this.temporaryAddress,
    this.roles = const [],
    this.userType,
    this.status = 'active',
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  static UserModel _systemUser = UserModel(
    id: systemId,
    uId: 'SU-01',
    fullname: 'Prasanna Aadhunik Krishi Kendra Pvt. Ltd.',
    email: 'prasannakrishi@hotmail.com',
    phone: '9858028096',
    permanentAddress: 'Ghorahi-15, Dang',
    temporaryAddress: 'Ghorahi-15, Dang',
    userType: 'system',
    roles: ['admin'],
    status: 'active',
    createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
  );

  static UserModel get systemUser => _systemUser;

  static void setSystemUser(UserModel user) {
    if (user.id != systemId) {
      throw ArgumentError('Invalid System User ID');
    }
    _systemUser = user;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['roles'];
    final roles = rawRoles is List
        ? rawRoles.map((role) => role.toString()).toList()
        : rawRoles == null
        ? <String>[]
        : [rawRoles.toString()];

    return UserModel(
      id: toStringValue(map['id']),
      uId: toStringValue(map['uId']),
      fullname: toStringValue(map['fullname']),
      email: map['email']?.toString(),
      phone: toStringValue(map['phone']),
      permanentAddress: map['permanentAddress']?.toString(),
      temporaryAddress: map['temporaryAddress']?.toString(),
      roles: roles,
      userType: map['userType']?.toString(),
      status: toStringValue(map['status'], defaultValue: 'active'),
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
      'fullname': fullname,
      'email': email,
      'phone': phone,
      'permanentAddress': permanentAddress,
      'temporaryAddress': temporaryAddress,
      'roles': roles,
      'userType': userType,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  factory UserModel.empty() {
    return UserModel(
      id: '',
      uId: '',
      fullname: '',
      phone: '',
      roles: [],
      status: 'active',
      createdAt: DateTime.now(),
    );
  }

  String get name => fullname;
}
