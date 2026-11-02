import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_karobar/offline/offline_exceptions.dart';
import 'package:krishi_karobar/offline/offline_storage.dart';

void main() {
  setUp(OfflineStorage.resetForTest);
  tearDown(OfflineStorage.resetForTest);

  test('a save is refused with the specific reason when offline storage is unavailable',
      () async {
    expect(OfflineStorage.isAvailable, isFalse);
    expect(OfflineStorage.unavailableReason, isNotNull);

    await expectLater(
      OfflineStorage.saveLocalOrThrow(
        entityType: 'customers',
        recordId: 'c1',
        data: {'id': 'c1'},
        isNew: true,
      ),
      throwsA(isA<OfflineStorageException>()),
    );
    expect(OfflineStorage.lastSaveError, OfflineStorage.unavailableReason);
    expect(OfflineStorage.requireAvailable, throwsA(isA<OfflineStorageException>()));
  });

  test('a failed database start is reported as the reason, not hidden', () async {
    await expectLater(
      OfflineStorage.initializeWith(() async => throw StateError('disk full')),
      throwsA(isA<OfflineStorageException>()),
    );

    expect(OfflineStorage.isAvailable, isFalse);
    expect(OfflineStorage.initializationError, isNotNull);
    expect(
      OfflineStorage.unavailableReason,
      OfflineStorage.initializationError!.message,
    );
  });

  test('only local save failures are treated as such', () {
    expect(OfflineStorage.isLocalSaveFailure(const OfflineStorageException.unavailable()), isTrue);
    expect(OfflineStorage.isLocalSaveFailure(const OfflineScopeException.noWorkspace()), isTrue);
    expect(OfflineStorage.isLocalSaveFailure(const OfflineDataException.invalid()), isTrue);
    expect(OfflineStorage.isLocalSaveFailure(const WorkspaceOwnershipException.differentOwner()), isTrue);
    expect(OfflineStorage.isLocalSaveFailure(StateError('sequence lookup failed')), isFalse);
  });

  test('an unrelated error is wrapped so callers can recognise a failed save', () {
    final wrapped = OfflineStorage.asSaveFailure(StateError('sembast broke'));
    expect(wrapped, isA<OfflineStorageException>());
    expect((wrapped as OfflineStorageException).code, 'offline-save-failed');

    const local = OfflineDataException.stale();
    expect(identical(OfflineStorage.asSaveFailure(local), local), isTrue);
  });
}
