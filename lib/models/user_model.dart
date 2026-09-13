import '../utils/helper/helper_method.dart';
import 'user_roles.dart';
import 'user_types.dart';

class UserModel {
  static const String systemId = '00000000-0000-0000-0000-000000000000';

  final String id;
  final String uId;
  String nId;
  String fullname;
  String phone;
  String? email;
  String? permanentAddress;
  List<String> assignedVehicleIds;
  List<String> roles;
  String userType;
  String status;
  final DateTime createdAt;
  String? createdBy;
  DateTime? updatedAt;
  String? updatedBy;

  UserModel({
    required this.id,
    required this.uId,
    required this.nId,
    required this.fullname,
    required this.phone,
    this.email,
    this.permanentAddress,
    List<String>? assignedVehicleIds,
    List<String>? roles,
    this.userType = UserTypes.organization,
    this.status = 'active',
    required this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  })  : assignedVehicleIds = assignedVehicleIds ?? [],
        roles = _normalizeRoles(roles ?? []);

  static List<String> _normalizeRoles(List<String> roles) {
    return roles
        .map((role) => role.trim().toLowerCase())
        .where(UserRoles.isValid)
        .toSet()
        .toList();
  }

  static String _normalizeUserType(String? userType) {
    final value = userType?.trim().toLowerCase();

    if (value == UserTypes.organization) return UserTypes.organization;
    if (value == UserTypes.external) return UserTypes.external;
    if (value == UserTypes.guest) return UserTypes.guest;
    if (value == UserTypes.system) return UserTypes.system;

    return UserTypes.organization;
  }

  static UserModel _systemUser = UserModel(
    id: systemId,
    uId: 'SU-01',
    nId: 'SU-01',
    fullname: 'Prasanna Aadhunik Krishi Kendra Pvt. Ltd.',
    phone: '9858028096',
    email: 'prasannakrishi@hotmail.com',
    permanentAddress: 'Ghorahi-15, Dang',
    userType: UserTypes.system,
    roles: [UserRoles.admin],
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

    final userType = _normalizeUserType(map['userType']?.toString());

    final rawVehicleIds = map['assignedVehicleIds'];
    final assignedVehicleIds = rawVehicleIds is List
        ? rawVehicleIds
            .map((v) => v.toString())
            .where((v) => v.isNotEmpty)
            .toList()
        : (map['assignedVehicleId']?.toString().isNotEmpty ?? false)
            ? [map['assignedVehicleId'].toString()]
            : <String>[];

    return UserModel(
      id: toStringValue(map['id'] ?? map['guid']),
      uId: toStringValue(map['uId'] ?? map['uid']),
      nId: toStringValue(map['nId']),
      fullname: toStringValue(map['fullname']),
      phone: toStringValue(map['phone']),
      email: map['email']?.toString(),
      permanentAddress: map['permanentAddress']?.toString() ?? map['address']?.toString(),
      assignedVehicleIds: assignedVehicleIds,
      roles: userType == UserTypes.guest ? [] : roles,
      userType: userType,
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
      'nId': nId,
      'fullname': fullname,
      'phone': phone,
      'email': email,
      'permanentAddress': permanentAddress,
      'assignedVehicleIds': List<String>.from(assignedVehicleIds),
      'roles': List<String>.from(roles),
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
      nId: '',
      fullname: '',
      phone: '',
      roles: [],
      userType: UserTypes.organization,
      status: 'active',
      createdAt: DateTime.now(),
    );
  }

  bool get isSystem => userType == UserTypes.system;
  bool get isOrganization => userType == UserTypes.organization;
  bool get isExternal => userType == UserTypes.external;
  bool get isGuest => userType == UserTypes.guest;

  bool hasRole(String role) {
    return roles.contains(role);
  }

  /// True if [role] is legal for this user's current userType
  /// (spec section 6/13 - userType+role validity matrix).
  bool isRoleAllowed(String role) =>
      UserRoles.isAllowedForUserType(role, userType);

  /// Organization admins/super-admins are treated as having access to every
  /// vehicle rather than a hand-picked list.
  bool get hasAllVehicleAccess =>
      hasRole(UserRoles.admin) || hasRole(UserRoles.superAdmin);

  String get name => fullname;
}