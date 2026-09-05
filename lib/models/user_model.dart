import 'package:krishi_karobar/models/models.dart';

class UserModel {
  static const String systemGuid = '00000000-0000-0000-0000-000000000000';

  final String guid;
  final String uid;

  String fullname;
  String? email;
  String phone;
  String? permanentAddress;
  String? temporaryAddress;

  List<UserRole> roles;
  UserType? userType;
  UserStatus status;

  final DateTime createdAt;
  String? createdBy;

  DateTime? updatedAt;
  String? updatedBy;

  UserModel({
    required this.guid,
    required this.uid,
    required this.fullname,
    this.email,
    required this.phone,
    this.permanentAddress,
    this.temporaryAddress,
    this.roles = const [],
    this.userType,
    this.status = UserStatus.active,
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  static UserModel _systemUser = UserModel(
    guid: systemGuid,
    uid: 'SU-01',
    fullname: 'Prasanna Aadhunik Krishi Kendra Pvt. Ltd.',
    email: 'prasannakrishi@hotmail.com',
    phone: '9858028096',
    permanentAddress: 'Ghorahi-15, Dang',
    temporaryAddress: 'Ghorahi-15, Dang',
    userType: UserType.system,
    roles: [UserRole.admin],
    status: UserStatus.active,
    createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
  );

  static UserModel get systemUser => _systemUser;

  static void setSystemUser(UserModel user) {
    if (user.guid != systemGuid) {
      throw Exception('Invalid System User GUID');
    }
    _systemUser = user;
  }

  static T? _enumFromName<T extends Enum>(
      Iterable<T> values,
      String? name,
    ) {
    if (name == null) return null;

    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['roles'];

    final roleItems = rawRoles is List
        ? rawRoles
        : rawRoles == null
        ? <dynamic>[]
        : <dynamic>[rawRoles];

    return UserModel(
      guid: (map['guid'] ?? map['id'] ?? '').toString(),
      uid: (map['uid'] ?? '').toString(),
      fullname: (map['fullname'] ?? map['name'] ?? '').toString(),
      email: map['email']?.toString(),
      phone: (map['phone'] ?? '').toString(),
      permanentAddress:
      (map['permanentAddress'] ?? map['address'] ?? '').toString(),
      temporaryAddress:
      (map['temporaryAddress'] ?? map['address'] ?? '').toString(),
      roles: roleItems.map((role) => _enumFromName
          (
            UserRole.values,
            role?.toString(),
          ),
        ).whereType<UserRole>().toList(),
      userType: _enumFromName(
        UserType.values,
        (map['userType'] ?? map['usertype'])?.toString(),
      ),
      status: _enumFromName(UserStatus.values,map['status']?.toString(),) ??UserStatus.active,
      createdAt: map['createdAt'] != null? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
      createdBy: map['createdBy']?.toString(),
      updatedAt: map['updatedAt'] != null? DateTime.tryParse(map['updatedAt'].toString()): null,
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'guid': guid,
      'uid': uid,
      'fullname': fullname,
      'name': fullname,
      'email': email,
      'phone': phone,
      'permanentAddress': permanentAddress,
      'temporaryAddress': temporaryAddress,
      'address': permanentAddress,
      'roles': roles.map((role) => role.name).toList(),
      'userType': userType?.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  factory UserModel.empty() {
    return UserModel(
      guid: '',
      uid: '',
      fullname: '',
      phone: '',
      permanentAddress: '',
      temporaryAddress: '',
      roles: [],
      userType: null,
      status: UserStatus.active,
      createdAt: DateTime.now(),
    );
  }

  String get name => fullname;
}
