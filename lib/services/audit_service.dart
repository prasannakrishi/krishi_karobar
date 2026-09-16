import 'package:uuid/uuid.dart';

import 'firebase_service.dart';

/// Centralized audit logging (spec section 22).
///
/// Writes a lightweight, append-only record of privileged/security-relevant
/// events to the 'audit_logs' node. This does NOT replace real server-side
/// auditing - a malicious client could in theory skip calling this - but it
/// gives the app a single, reusable place to record these events instead of
/// scattering ad-hoc writes, and is enough for an admin "audit log" screen.
class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  final FirebaseService _firebaseService = FirebaseService();
  final Uuid _uuid = const Uuid();

  Future<void> log({
    required String action,
    required String performedBy,
    String? targetUserId,
    String? targetRecordId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _firebaseService.saveRecord('audit_logs', id, {
      'id': id,
      'action': action,
      'performedBy': performedBy,
      'targetUserId': targetUserId,
      'targetRecordId': targetRecordId,
      'oldValue': oldValue,
      'newValue': newValue,
      'timestamp': now.toIso8601String(),
    });
  }
}
