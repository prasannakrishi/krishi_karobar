import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import '../utils/exceptions/app_exceptions.dart';
import 'firebase_service.dart';

/// Resolves the Firebase Auth identity into the business user record:
///
///   auth.uid -> authUsers/{auth.uid}.recordId -> users/{recordId}
///
/// Each failure along that chain throws a distinct [AppException] so the
/// caller can tell "no mapping" from "inactive account" from "record
/// missing" from "permission denied".
class UserProfileResolver {
  UserProfileResolver({
    FirebaseService? firebaseService,
  }) : _firebaseService = firebaseService ?? FirebaseService();

  final FirebaseService _firebaseService;

  Future<UserModel> resolve(User firebaseUser) async {
    final authUid = firebaseUser.uid.trim();

    if (authUid.isEmpty) {
      throw const AuthenticationException.required();
    }

    final authData = await _firebaseService.getRecordById(
      'authUsers',
      authUid,
    );

    if (authData == null) {
      throw const AuthenticationException.profileNotLinked(
        details: 'authUsers mapping missing',
      );
    }

    _requireUsableStatus(
      authData['status']?.toString(),
      details: 'authUsers/$authUid',
    );

    final recordId = authData['recordId']?.toString().trim();

    if (recordId == null || recordId.isEmpty) {
      throw const DataValidationException(
        code: 'missing-record-id',
        details: 'authUsers.recordId is empty',
      );
    }

    final user = await resolveById(recordId);

    _requireUsableStatus(user.status, details: 'users/$recordId');

    return user;
  }

  Future<UserModel> resolveById(String id) async {
    final userId = id.trim();

    if (userId.isEmpty) {
      throw const DataValidationException(
        code: 'missing-record-id',
        details: 'resolveById received an empty id',
      );
    }

    final data = await _firebaseService.getRecordById('users', userId);

    if (data == null) {
      throw RecordNotFoundException(details: 'users/$userId');
    }

    final UserModel user;

    try {
      user = UserModel.fromMap(data);
    } catch (error) {
      throw DataValidationException(
        code: 'user-parse-failed',
        details: 'users/$userId :: $error',
      );
    }

    if (user.id != userId) {
      throw DataValidationException(
        code: 'record-id-mismatch',
        details: 'users/$userId holds id ${user.id}',
      );
    }

    return user;
  }

  void _requireUsableStatus(String? status, {required String details}) {
    final value = status?.trim().toLowerCase();

    if (value == 'active') return;

    if (value == 'suspended') {
      throw AuthenticationException.suspendedAccount(details: details);
    }

    throw AuthenticationException.inactiveAccount(details: details);
  }
}
