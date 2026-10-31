import 'package:nepali_utils/nepali_utils.dart';

double toDouble(
    dynamic value, {
      double defaultValue = 0.0,
    }) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();

  return double.tryParse(value.toString()) ?? defaultValue;
}

int toInt(
    dynamic value, {
      int defaultValue = 0,
    }) {
  if (value == null) return defaultValue;
  if (value is int) return value.toInt();

  return int.tryParse(value.toString()) ?? defaultValue;
}

String toStringValue(
    dynamic value, {
      String defaultValue = '',
    }) {
  return value?.toString() ?? defaultValue;
}

bool toBool(
    dynamic value, {
      bool defaultValue = false,
    }) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalizedValue = value.toString().trim().toLowerCase();

  switch (normalizedValue) {
    case 'true':
    case '1':
    case 'yes':
      return true;

    case 'false':
    case '0':
    case 'no':
      return false;

    default:
      return defaultValue;
  }
}

/// Converts any input value (ISO String, Nepali BS String "YYYY-MM-DD",
/// or Epoch timestamp) into a valid Gregorian DateTime for filtering and storing.
DateTime? toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;

  if (value is num) {
    final numVal = value.toInt();
    if (numVal > 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(numVal, isUtc: true);
    }
    if (numVal > 100000000) {
      return DateTime.fromMillisecondsSinceEpoch(numVal * 1000, isUtc: true);
    }
  }

  final rawStr = value.toString().trim();
  if (rawStr.isEmpty) return null;

  final parsed = DateTime.tryParse(rawStr);

  if (parsed != null) {
    // If year is in Bikram Sambat range (2050 to 2100), convert BS -> AD
    if (parsed.year >= 2050 && parsed.year <= 2100) {
      try {
        final nepali = NepaliDateTime(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
        );
        return nepali.toDateTime();
      } catch (_) {
        return parsed;
      }
    }
    return parsed;
  }

  try {
    final cleanStr = rawStr.replaceAll('/', '-');
    final parts = cleanStr.split(RegExp(r'[\sT]+'));
    final dateParts = parts[0].split('-');

    if (dateParts.length == 3) {
      final y = int.tryParse(dateParts[0]);
      final m = int.tryParse(dateParts[1]);
      final d = int.tryParse(dateParts[2]);

      if (y != null && m != null && d != null) {
        int hour = 0, minute = 0, second = 0;

        if (parts.length > 1) {
          final timeParts = parts[1].split(':');
          if (timeParts.length >= 2) {
            hour = int.tryParse(timeParts[0]) ?? 0;
            minute = int.tryParse(timeParts[1]) ?? 0;
            if (timeParts.length >= 3) {
              second = int.tryParse(timeParts[2].split('.')[0]) ?? 0;
            }
          }
        }

        if (y >= 2050 && y <= 2100) {
          final nepali = NepaliDateTime(y, m, d, hour, minute, second);
          return nepali.toDateTime();
        } else {
          return DateTime(y, m, d, hour, minute, second);
        }
      }
    }
  } catch (_) {}

  return null;
}

List<T> removeDuplicates<T>(List<T> list) {
  return list.toSet().toList();
}

extension DateTimeExtensions on DateTime {
  DateTime get dayStartTime => DateTime(
    year,
    month,
    day,
  );

  DateTime get dayEndTime => DateTime(
    year,
    month,
    day,
    23,
    59,
    59,
  );
}

String secondsToHHMMSS(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}