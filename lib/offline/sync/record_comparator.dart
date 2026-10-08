/// One field that differs between the local and the server copy.
class FieldDifference {
  const FieldDifference({
    required this.field,
    required this.local,
    required this.server,
  });

  final String field;
  final Object? local;
  final Object? server;

  @override
  String toString() => 'FieldDifference($field: $local != $server)';
}

/// Compares a local/expected map with the server copy. Used for the
/// idempotent-create check, read-back verification and (later) the conflict
/// comparison screen.
class RecordComparator {
  RecordComparator._();

  static final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}T');

  /// Fields of [expected] whose value differs in [actual].
  ///
  /// Only the keys of [expected] are examined, so extra fields on the
  /// server do not count. `null` and a missing field are equal. When
  /// [actual] is null every non-null expected field is reported.
  static List<FieldDifference> differences({
    required Map<String, Object?> expected,
    required Map<String, Object?>? actual,
    Iterable<String> ignore = const [],
  }) {
    final skipped = ignore.toSet();
    final result = <FieldDifference>[];

    for (final entry in expected.entries) {
      if (skipped.contains(entry.key)) continue;

      final server = actual?[entry.key];
      if (!sameValue(entry.value, server)) {
        result.add(
          FieldDifference(
            field: entry.key,
            local: entry.value,
            server: server,
          ),
        );
      }
    }

    return result;
  }

  static bool matches({
    required Map<String, Object?> expected,
    required Map<String, Object?>? actual,
    Iterable<String> ignore = const [],
  }) {
    return differences(expected: expected, actual: actual, ignore: ignore)
        .isEmpty;
  }

  static bool sameValue(Object? a, Object? b) {
    if (a == null || b == null) return a == null && b == null;

    if (a is num && b is num) return a == b;

    if (a is String && b is String) {
      if (a == b) return true;

      if (_isoDate.hasMatch(a) && _isoDate.hasMatch(b)) {
        final left = DateTime.tryParse(a);
        final right = DateTime.tryParse(b);
        if (left != null && right != null) {
          return left.isAtSameMomentAs(right);
        }
      }

      return false;
    }

    if (a is Map && b is Map) {
      final keys = {...a.keys.map((k) => '$k'), ...b.keys.map((k) => '$k')};
      final left = {for (final e in a.entries) '${e.key}': e.value};
      final right = {for (final e in b.entries) '${e.key}': e.value};

      return keys.every((k) => sameValue(left[k], right[k]));
    }

    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!sameValue(a[i], b[i])) return false;
      }
      return true;
    }

    return a == b;
  }
}
