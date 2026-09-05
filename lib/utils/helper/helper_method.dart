import 'package:intl/intl.dart';

double toDouble(
    dynamic value, {
      double defaultValue = 0.0,
    }) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();

  return double.tryParse(value.toString()) ?? defaultValue;
}

int toInt(
    dynamic value, {
      int defaultValue = 0,
    }) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();

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

DateTime? toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;

  return DateTime.tryParse(value.toString());
}

String getFormattedDate(
    DateTime date, {
      String format = 'dd MMM yyyy',
    }) {
  return DateFormat(format).format(date);
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