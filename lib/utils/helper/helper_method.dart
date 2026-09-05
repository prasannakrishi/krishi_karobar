
import 'package:get/get.dart';
import 'package:krishi_karobar/models/models.dart';
import 'package:intl/intl.dart';
import 'package:krishi_karobar/services/data_cache_service.dart';

T enumFromString<T extends Enum>(
    Iterable<T> values,
    String? value,
    ) {
  return values.firstWhere(
        (item) => item.name == value,
    orElse: () {
      throw StateError(
        'Invalid enum value "$value" for ${T.toString()}',
      );
    },
  );
}

double toDouble(dynamic value, {double defaultValue = 0.0}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();

  return double.tryParse(value.toString()) ?? defaultValue;
}

int toInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();

  return int.tryParse(value.toString()) ?? defaultValue;
}

String toStringValue(dynamic value, {String defaultValue = ''}) {
  return value?.toString() ?? defaultValue;
}

bool toBool(dynamic value, {bool defaultValue = false}) {
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

T? lookup<T>(dynamic value) {
  if (value == null) return null;

  final cache = Get.isRegistered<DataCacheService>()
      ? DataCacheService.instance
      : null;

  switch (T) {
    case UserModel:
      if (value is Map<String, dynamic>) {
        return UserModel.fromMap(value) as T;
      } else if (value is String && value.isNotEmpty) {
        return (cache?.getUser(value) ?? UserModel.empty()) as T;
      }
      break;

    case CustomerModel:
      if (value is Map<String, dynamic>) {
        return CustomerModel.fromMap(value) as T;
      } else if (value is String && value.isNotEmpty) {
        return (cache?.getCustomer(value) ?? CustomerModel.empty()) as T;
      }
      break;

    case VehicleModel:
      if (value is Map<String, dynamic>) {
        return VehicleModel.fromMap(value) as T;
      } else if (value is String && value.isNotEmpty) {
        return (cache?.getVehicle(value) ?? VehicleModel.empty()) as T;
      }
      break;

    case ServiceModel:
      if (value is Map<String, dynamic>) {
        return ServiceModel.fromMap(value) as T;
      } else if (value is String && value.isNotEmpty) {
        return (cache?.getService(value) ?? ServiceModel.empty(value)) as T;
      }
      break;
  }

  return null;
}
extension DateTimeExtensions on DateTime {
  DateTime get dayStartTime => DateTime(year, month, day, 0, 0, 0);
  DateTime get dayEndTime => DateTime(year, month, day, 23, 59, 59);
}

