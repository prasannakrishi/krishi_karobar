import '../offline_exceptions.dart';

/// A formatted Expense uId plus the values it was built from.
class ExpenseUid {
  const ExpenseUid({
    required this.uId,
    required this.vehicleCode,
    required this.nepaliYear,
    required this.sequence,
  });

  /// e.g. `EV01-30001`.
  final String uId;

  /// e.g. `V01`.
  final String vehicleCode;

  /// Full Bikram Sambat year, e.g. 2083. Only the last digit is shown in
  /// [uId]; the full year is the sequence scope.
  final int nepaliYear;
  final int sequence;

  @override
  String toString() => 'ExpenseUid($uId, year: $nepaliYear)';
}

/// What can be read back from a uId string. The full year is NOT in the
/// string (2083 and 2093 both show `3`); it comes from the record's
/// `createdAt`.
class ExpenseUidParts {
  const ExpenseUidParts({
    required this.vehicleCode,
    required this.yearDigit,
    required this.sequence,
  });

  final String vehicleCode;
  final int yearDigit;
  final int sequence;
}

/// Expense uId convention: `E` + vehicle code + `-` + last digit of the
/// Nepali year + sequence padded to 4 digits.
///
///   EV01-30001  ->  Expense, Vehicle V01, year ...3 (2083), sequence 1
///
/// This is the only new uId convention. Activity, Customer, Payment,
/// Service, User and Vehicle keep their existing generators untouched.
class ExpenseUidFormat {
  ExpenseUidFormat._();

  static const String prefix = 'E';
  static const int sequenceWidth = 4;

  static final RegExp _vehicleCodePattern = RegExp(r'^[A-Z0-9]+$');
  static final RegExp _uIdPattern = RegExp(r'^E([A-Z0-9]+)-(\d)(\d{4,})$');

  /// Trims and upper-cases [vehicleCode]; throws when it is empty or
  /// contains anything but letters and digits (a `-` would break parsing).
  static String normalizeVehicleCode(String vehicleCode) {
    final code = vehicleCode.trim().toUpperCase();

    if (code.isEmpty || !_vehicleCodePattern.hasMatch(code)) {
      throw ExpenseUidException.invalid(
        message: 'The vehicle code "$vehicleCode" cannot be used in an '
            'Expense uId.',
      );
    }

    return code;
  }

  /// Vehicle code for an Expense uId, derived from the vehicle's own uId:
  /// `V` + its serial number, at least two digits.
  ///
  ///   VT3-01   -> V01
  ///   VT6-0001 -> V01   (existing vehicles use a 4-digit serial)
  ///   VH6-0012 -> V12
  ///
  /// The type letter and year digit are ignored. Throws when [vehicleUId]
  /// is not a `V...` vehicle uId, so a bad value never produces a wrong
  /// code silently.
  static String vehicleCodeFromVehicleUId(String vehicleUId) {
    final match =
        RegExp(r'^V[A-Z]*\d-(\d+)$').firstMatch(vehicleUId.trim().toUpperCase());
    final serial = match == null ? null : int.tryParse(match.group(1)!);

    if (serial == null || serial < 1) {
      throw ExpenseUidException.invalid(
        message: 'The vehicle uId "$vehicleUId" cannot be turned into an '
            'Expense vehicle code.',
      );
    }

    return 'V${serial.toString().padLeft(2, '0')}';
  }

  static ExpenseUid build({
    required String vehicleCode,
    required int nepaliYear,
    required int sequence,
  }) {
    final code = normalizeVehicleCode(vehicleCode);

    if (nepaliYear < 2000 || nepaliYear > 2200) {
      throw ExpenseUidException.invalid(
        message: 'The Nepali year $nepaliYear is outside the supported range.',
      );
    }

    if (sequence < 1) {
      throw ExpenseUidException.invalid(
        message: 'An Expense sequence must start at 1.',
      );
    }

    final digit = nepaliYear % 10;
    final number = sequence.toString().padLeft(sequenceWidth, '0');

    return ExpenseUid(
      uId: '$prefix$code-$digit$number',
      vehicleCode: code,
      nepaliYear: nepaliYear,
      sequence: sequence,
    );
  }

  /// Returns `null` when [uId] is not in the new Expense format (for
  /// example an existing record such as `E6-0001`).
  static ExpenseUidParts? tryParse(String uId) {
    final match = _uIdPattern.firstMatch(uId.trim());
    if (match == null) return null;

    return ExpenseUidParts(
      vehicleCode: match.group(1)!,
      yearDigit: int.parse(match.group(2)!),
      sequence: int.parse(match.group(3)!),
    );
  }

  static bool isExpenseUid(String uId) => tryParse(uId) != null;
}
