import 'package:sembast/sembast.dart';

import '../offline_constants.dart';
import '../offline_models.dart';

/// `local_sequences`: per entity + scope + year counters used to give
/// offline records a provisional `uId`.
///
/// Rules enforced here:
///  * numbers never decrement and are never handed out twice;
///  * deleting a record never touches a counter;
///  * counters are not workspace data and survive a workspace clear
///    (they hold no business content, and resetting them could reuse a
///    number).
///
/// [scopeKey] and [yearKey] are opaque to this DAO. The UID service decides
/// what they contain (e.g. vehicle code and full Nepali year).
class LocalSequenceDao {
  LocalSequenceDao(this._db);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store(OfflineStores.localSequences);

  DatabaseClient _c(DatabaseClient? client) => client ?? _db;

  static String keyOf(String entityKey, String scopeKey, String yearKey) {
    for (final part in [entityKey, scopeKey, yearKey]) {
      if (part.trim().isEmpty || part.contains('|')) {
        throw ArgumentError('Invalid local sequence key part: "$part".');
      }
    }
    return '$entityKey|$scopeKey|$yearKey';
  }

  Future<LocalSequence?> peek(
    String entityKey,
    String scopeKey,
    String yearKey, {
    DatabaseClient? client,
  }) async {
    final value = await _store
        .record(keyOf(entityKey, scopeKey, yearKey))
        .get(_c(client));

    return value == null ? null : LocalSequence.fromMap(value);
  }

  /// Hands out `max(lastIssued, lastKnownServer) + 1` and records it.
  ///
  /// Pass the surrounding transaction as [client] so the number is issued
  /// atomically with the record that uses it; with no client it runs in
  /// its own transaction.
  Future<int> allocateNext(
    String entityKey,
    String scopeKey,
    String yearKey, {
    DatabaseClient? client,
  }) {
    if (client != null) {
      return _allocate(entityKey, scopeKey, yearKey, client);
    }

    return _db.transaction(
      (txn) => _allocate(entityKey, scopeKey, yearKey, txn),
    );
  }

  /// Remembers the server counter seen while online. Never lowers it.
  Future<LocalSequence> recordServerSequence(
    String entityKey,
    String scopeKey,
    String yearKey,
    int serverValue, {
    DatabaseClient? client,
  }) {
    return _raise(
      entityKey,
      scopeKey,
      yearKey,
      client,
      serverValue: serverValue,
    );
  }

  /// Raises the issued marker to at least [value] (used when sync
  /// renumbers a record). Never lowers it.
  Future<LocalSequence> recordIssuedAtLeast(
    String entityKey,
    String scopeKey,
    String yearKey,
    int value, {
    DatabaseClient? client,
  }) {
    return _raise(
      entityKey,
      scopeKey,
      yearKey,
      client,
      issuedValue: value,
    );
  }

  Future<int> _allocate(
    String entityKey,
    String scopeKey,
    String yearKey,
    DatabaseClient client,
  ) async {
    final key = keyOf(entityKey, scopeKey, yearKey);
    final value = await _store.record(key).get(client);

    final current = value == null
        ? LocalSequence(
            entityKey: entityKey,
            scopeKey: scopeKey,
            yearKey: yearKey,
            lastIssuedSequence: 0,
            lastKnownServerSequence: 0,
            updatedAt: DateTime.now().toUtc(),
          )
        : LocalSequence.fromMap(value);

    final next = current.nextSequence;

    await _store.record(key).put(
          client,
          LocalSequence(
            entityKey: entityKey,
            scopeKey: scopeKey,
            yearKey: yearKey,
            lastIssuedSequence: next,
            lastKnownServerSequence: current.lastKnownServerSequence,
            updatedAt: DateTime.now().toUtc(),
          ).toMap(),
        );

    return next;
  }

  Future<LocalSequence> _raise(
    String entityKey,
    String scopeKey,
    String yearKey,
    DatabaseClient? client, {
    int? serverValue,
    int? issuedValue,
  }) async {
    Future<LocalSequence> run(DatabaseClient c) async {
      final key = keyOf(entityKey, scopeKey, yearKey);
      final value = await _store.record(key).get(c);

      final current = value == null
          ? LocalSequence(
              entityKey: entityKey,
              scopeKey: scopeKey,
              yearKey: yearKey,
              lastIssuedSequence: 0,
              lastKnownServerSequence: 0,
              updatedAt: DateTime.now().toUtc(),
            )
          : LocalSequence.fromMap(value);

      final updated = LocalSequence(
        entityKey: entityKey,
        scopeKey: scopeKey,
        yearKey: yearKey,
        lastIssuedSequence:
            issuedValue != null && issuedValue > current.lastIssuedSequence
                ? issuedValue
                : current.lastIssuedSequence,
        lastKnownServerSequence: serverValue != null &&
                serverValue > current.lastKnownServerSequence
            ? serverValue
            : current.lastKnownServerSequence,
        updatedAt: DateTime.now().toUtc(),
      );

      await _store.record(key).put(c, updated.toMap());
      return updated;
    }

    if (client != null) return run(client);
    return _db.transaction(run);
  }
}
