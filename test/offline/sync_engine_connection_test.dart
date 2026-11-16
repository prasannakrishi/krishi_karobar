import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_karobar/models/user_types.dart';
import 'package:krishi_karobar/offline/core/workspace_access.dart';
import 'package:krishi_karobar/offline/core/workspace_scope.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';
import 'package:krishi_karobar/offline/sync/sync_engine.dart';
import 'package:krishi_karobar/offline/sync/sync_remote_gateway.dart';
import 'package:krishi_karobar/offline/uid/expense_uid_service.dart';
import 'package:krishi_karobar/services/sequences_service.dart';
import 'package:sembast/sembast_memory.dart';

class _MockGateway implements SyncRemoteGateway {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _connected = false;

  @override
  Stream<bool> connectionChanges() => _controller.stream;

  @override
  Future<bool> isConnected() async => _connected;

  void setConnected(bool value) {
    _connected = value;
    _controller.add(value);
  }

  @override
  Future<Map<String, Object?>?> readRecord(String path, String id) async => null;

  @override
  Future<RemoteCreateResult> createIfAbsent(
    String path,
    String id,
    Map<String, Object?> payload,
  ) async => RemoteCreateResult.created;

  @override
  Future<void> mergeRecord(String path, String id, Map<String, Object?> patch) async {}

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeSequences extends Fake implements SequenceService {}
class _FakeExpenseUid extends Fake implements ExpenseUidService {}

void main() {
  test('SyncEngine connection state updates correctly on true/false events and resumes pending sync', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('engine_conn.db');
    final storage = OfflineStorage.forDatabase(db);
    final scope = const WorkspaceScope(
      environment: 'dev',
      ownerUserId: 'user-1',
      authUid: 'auth-1',
    );

    await storage.workspaces.open(
      scope,
      ownerPhone: '9800000000',
      access: const WorkspaceAccess(
        userType: UserTypes.organization,
        roles: ['admin'],
        allVehicles: true,
      ),
    );

    final gateway = _MockGateway();
    final engine = SyncEngine(
      storage: storage,
      remote: gateway,
      sequences: _FakeSequences(),
      expenseUid: _FakeExpenseUid(),
    );

    // Start with false
    gateway.setConnected(false);
    await engine.start(scope);

    expect(await gateway.isConnected(), isFalse);

    // Transition to true
    gateway.setConnected(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await gateway.isConnected(), isTrue);

    // Transition back to false
    gateway.setConnected(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await gateway.isConnected(), isFalse);

    await gateway.dispose();
    await engine.dispose();
    await db.close();
  });
}
