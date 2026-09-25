import 'package:flutter/material.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart' as np;
import 'package:nepali_utils/nepali_utils.dart';

/// Every date/time shown to the user in this app is shown in Nepal
/// Standard Time (UTC+05:45, no DST) using the Bikram Sambat calendar -
/// never the device's own timezone or the Gregorian calendar. This is the
/// single place that conversion happens; screens should call these
/// functions instead of `DateFormat`/`.toLocal()`/manual field access.
const Duration _nepalOffset = Duration(hours: 5, minutes: 45);

/// Shifts [dateTime] (device-local or UTC) to Nepal Standard Time
/// wall-clock fields. The result's year/month/day/hour/minute are the
/// correct NPT reading regardless of the device's own timezone - do not
/// call [DateTime.toLocal] on it afterward, that would re-apply the
/// device's zone on top of this shift.
DateTime toNepalStandardTime(DateTime dateTime) {
  return dateTime.toUtc().add(_nepalOffset);
}

/// Converts to the Bikram Sambat calendar, anchored to Nepal Standard Time.
NepaliDateTime toNepaliCalendar(DateTime dateTime) {
  return dateTime.toNepaliDateTime();
}

/// Full Nepali date, e.g. "5 Mangsir 2083".
String formatNepaliDate(
    DateTime dateTime, {
      String pattern = 'd MMMM yyyy',
    }) {
  return NepaliDateFormat(pattern).format(toNepaliCalendar(dateTime));
}

/// Nepal Standard Time of day, e.g. "11:05 AM". A time-of-day pattern is
/// unaffected by which calendar the date part uses, so this reuses the
/// same NPT-shifted value as the date formatter for consistency.
String formatNepaliTime(
    DateTime dateTime, {
      String pattern = 'h:mm a',
    }) {
  return NepaliDateFormat(pattern).format(toNepaliCalendar(dateTime));
}

/// Combined date + time, e.g. "5 Mangsir 2083, 11:05 AM".
String formatNepaliDateTime(
    DateTime dateTime, {
      String pattern = 'd MMMM yyyy, h:mm a',
    }) {
  return NepaliDateFormat(pattern).format(toNepaliCalendar(dateTime));
}

/// Compact numeric date, e.g. "2083-08-05" - for table cells and filenames
/// where a short, sortable value reads better than the full month name.
String formatNepaliDateShort(DateTime dateTime) {
  return formatNepaliDate(dateTime, pattern: 'yyyy-MM-dd');
}

/// Compact numeric date + time, e.g. "2083-08-05 11:05".
String formatNepaliDateTimeShort(DateTime dateTime) {
  return formatNepaliDateTime(dateTime, pattern: 'yyyy-MM-dd HH:mm');
}

/// [calendarDate]'s fields (as returned by [pickNepaliDate]/
/// [pickNepaliDateRange] or [NepaliDateTime.toDateTime] - a calendar day
/// with no meaningful timezone attached) mapped to the true UTC instant of
/// that day's start (or end) in Nepal Standard Time. Compare the result
/// directly against stored UTC timestamps (`activity.createdAt`,
/// `payment.paidAt`, ...) - this is correct regardless of the device's own
/// timezone, unlike comparing via [DateTime.toLocal].
DateTime nepalCalendarDayBoundary(
    DateTime calendarDate, {
      bool endOfDay = false,
    }) {
  final startOfDayUtc = DateTime.utc(
    calendarDate.year,
    calendarDate.month,
    calendarDate.day,
  ).subtract(_nepalOffset);

  if (!endOfDay) return startOfDayUtc;

  return startOfDayUtc
      .add(const Duration(days: 1))
      .subtract(const Duration(milliseconds: 1));
}

/// Bikram Sambat equivalents of Flutter's [showDatePicker]/
/// [showDateRangePicker]. This app only operates in Nepal, so every date
/// picked anywhere in the app is picked on the BS calendar - never the
/// Gregorian calendar.
///
/// All inputs (`initialDate`, `firstDate`, `lastDate`,
/// `initialDateRange`) must be real instants (e.g. `DateTime.now()`, or a
/// UTC timestamp from Firebase / [nepalCalendarDayBoundary]) - they are
/// converted to their Nepal Standard Time calendar day via
/// [toNepaliCalendar]. The return value is a calendar day only (no
/// meaningful time-of-day or timezone attached); pass it through
/// [nepalCalendarDayBoundary] before comparing it against a stored
/// timestamp or storing it yourself.
Future<DateTime?> pickNepaliDate({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final picked = await np.showNepaliDatePicker(
    context: context,
    initialDate: toNepaliCalendar(initialDate ?? DateTime.now()),
    firstDate: toNepaliCalendar(firstDate ?? DateTime(2020)),
    lastDate: toNepaliCalendar(lastDate ?? DateTime(2050)),
  );

  return picked?.toDateTime();
}

/// Bikram Sambat equivalent of Flutter's [showDateRangePicker]. See
/// [pickNepaliDate] for the input/output contract.
Future<DateTimeRange<DateTime>?> pickNepaliDateRange({
  required BuildContext context,
  DateTimeRange<DateTime>? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final range = await np.showNepaliDateRangePicker(
    context: context,
    firstDate: toNepaliCalendar(firstDate ?? DateTime(2020)),
    lastDate: toNepaliCalendar(lastDate ?? DateTime(2050)),
    initialDateRange: initialDateRange == null
        ? null
        : DateTimeRange(
      start: toNepaliCalendar(initialDateRange.start),
      end: toNepaliCalendar(initialDateRange.end),
    ),
  );

  if (range == null) return null;

  return DateTimeRange(
    start: range.start.toDateTime(),
    end: range.end.toDateTime(),
  );
}
