import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'firebase_service.dart';

class UserProfileResolver {
  UserProfileResolver({
    FirebaseService? firebaseService,
  }) : _firebaseService = firebaseService ?? FirebaseService();

  final FirebaseService _firebaseService;

  Future<UserModel?> resolve(User firebaseUser) async {
    final authUid = firebaseUser.uid.trim();
    if (authUid.isEmpty) return null;

    final authData = await _firebaseService.getRecordById(
      'authUsers',
      authUid,
    );

    if (authData == null) return null;

    final status = authData['status']?.toString().trim().toLowerCase();
    if (status != 'active') return null;

    final recordId = authData['recordId']?.toString().trim();
    if (recordId == null || recordId.isEmpty) return null;

    final user = await resolveById(recordId);
    if (user == null) return null;
    if (user.status.trim().toLowerCase() != 'active') return null;

    return user;
  }

  Future<UserModel?> resolveById(String id) async {
    final userId = id.trim();
    if (userId.isEmpty) return null;

    final data = await _firebaseService.getRecordById(
      'users',
      userId,
    );

    if (data == null) return null;

    try {
      final user = UserModel.fromMap(data);
      if (user.id != userId) return null;
      return user;
    } catch (_) {
      return null;
    }
  }
}