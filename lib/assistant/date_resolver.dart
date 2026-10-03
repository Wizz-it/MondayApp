import 'package:flutter/foundation.dart';

import '../utils/date_labels.dart';
import 'assistant_action.dart';

/// Where the assistant gets the time from. Read once per request, so every
/// step of that request agrees on what "now" is.
typedef Clock = DateTime Function();

/// A time of day, without a date.
@immutable
class ClockTime {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// This time on [day], in local time.
  DateTime on(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

// Results -------------------------------------------------------------------

sealed class DayResolution {
  const DayResolution();
}

final class ResolvedDay extends DayResolution {
  const ResolvedDay(this.day);

  /// Local midnight of the resolved day.
  final DateTime day;
}

/// The reference does not name a real date, such as 31 February.
final class InvalidDay extends DayResolution {
  const InvalidDay(this.reason);

  final String reason;
}

sealed class TimeResolution {
  const TimeResolution();
}

final class ExactTime extends TimeResolution {
  const ExactTime(this.time);

  final ClockTime time;
}

/// More than one reading is plausible ("jam 2": 02:00 or 14:00). Never
/// resolved by guessing; the user has to say which. The reading as spoken
/// comes first.
final class AmbiguousTime extends TimeResolution {
  const AmbiguousTime(this.readings);

  final List<ClockTime> readings;
}

/// The part of the day can't modify the hour ("jam 9 sore", "jam 19 pagi"),
/// so there is no reading to offer.
final class UnclearTime extends TimeResolution {
  const UnclearTime();
}

/// Outside any clock: hour 25, minute 70.
final class InvalidTime extends TimeResolution {
  const InvalidTime(this.reason);

  final String reason;
}

// Resolver ------------------------------------------------------------------

/// Turns what the user said into local dates and times, against a fixed
/// [now]. Pure and deterministic: the same input and [now] always give the
/// same answer, and nothing here reads the real clock.
///
/// Rules:
/// * "hari ini" / "besok" / "lusa" are today, +1 and +2 days.
/// * A weekday is its next occurrence, today included — unless it is today
///   and the requested time has already passed, then it is next week.
/// * "next week" is that weekday in the following Monday-to-Sunday week.
/// * A calendar date without a year is its next occurrence that is not
///   before today (29 February finds the next leap year). With a year it is
///   taken as said, even if it has passed; the validator decides what to do.
/// * Times keep local semantics; nothing is converted to UTC.
///
/// Hours, as said in Indonesian:
/// * 0, 7-12 and 13-23 without a part of the day mean exactly that hour
///   ("jam 7" is 07:00, "jam 12" is noon).
/// * 1-6 without a part of the day are ambiguous ("jam 2": 02:00 or 14:00).
/// * A part of the day modifies the spoken hour: pagi keeps it, siang keeps
///   11 and 12 and moves 1-5 to the afternoon, sore and malam move it to the
///   afternoon or evening. Each part only modifies the hours it can describe
///   (see [_modify]); anything else is unclear.
class DateResolver {
  DateResolver(DateTime now)
      : now = now,
        today = dayOf(now);

  final DateTime now;
  final DateTime today;

  /// The default hour for a part of the day said without an hour.
  static const daypartDefaults = {
    Daypart.pagi: ClockTime(8, 0),
    Daypart.siang: ClockTime(12, 0),
    Daypart.sore: ClockTime(16, 0),
    Daypart.malam: ClockTime(19, 0),
  };

  /// Resolves [ref] to a day. [at] is the time the user asked for, if any;
  /// it only matters for a weekday that is today.
  DayResolution resolveDay(DateRef ref, {ClockTime? at}) {
    switch (ref) {
      case RelativeDateRef(:final day):
        return ResolvedDay(_addDays(today, day.offset));

      case WeekdayDateRef(:final weekday, nextWeek: true):
        final nextMonday = _addDays(today, 8 - today.weekday);
        return ResolvedDay(_addDays(nextMonday, weekday - DateTime.monday));

      case WeekdayDateRef(:final weekday):
        var days = (weekday - today.weekday) % 7;
        if (days == 0 && at != null && at.on(today).isBefore(now)) days = 7;
        return ResolvedDay(_addDays(today, days));

      case CalendarDateRef(:final day, :final month, year: final int year):
        final date = _realDate(year, month, day);
        return date == null
            ? InvalidDay('$day/$month/$year is not a date')
            : ResolvedDay(date);

      case CalendarDateRef(:final day, :final month):
        // Eight years always contains a leap year, so 29 February resolves.
        for (var year = today.year; year <= today.year + 8; year++) {
          final date = _realDate(year, month, day);
          if (date != null && !date.isBefore(today)) return ResolvedDay(date);
        }
        return InvalidDay('$day/$month is not a date');
    }
  }

  TimeResolution resolveTime(TimeRef ref) {
    final hour = ref.hour;
    final minute = ref.minute ?? 0;
    final daypart = ref.daypart;

    if (hour == null) {
      return daypart == null
          ? const InvalidTime('no hour and no part of the day')
          : ExactTime(daypartDefaults[daypart]!);
    }
    if (hour < 0 || hour > 23) return InvalidTime('hour $hour');
    if (minute < 0 || minute > 59) return InvalidTime('minute $minute');

    if (daypart == null) {
      // Early hours are the genuinely ambiguous ones: "jam 2" is as likely
      // to be the afternoon. "jam 7" to "jam 12" are taken as said.
      return hour >= 1 && hour <= 6
          ? AmbiguousTime(
              [ClockTime(hour, minute), ClockTime(hour + 12, minute)],
            )
          : ExactTime(ClockTime(hour, minute));
    }

    // "jam 19 malam" is fine; "jam 19 pagi" is not. A 24-hour hour is checked
    // by modifying its 12-hour form and seeing whether it comes back.
    final spoken = hour > 12 ? hour - 12 : hour;
    final modified = _modify(spoken, daypart);
    if (modified == null || (hour > 12 && modified != hour)) {
      return const UnclearTime();
    }
    return ExactTime(ClockTime(modified, minute));
  }

  /// The 24-hour hour for a spoken 12-hour [hour] in [daypart], or null when
  /// that part of the day does not describe that hour.
  ///
  /// | daypart | modifies   | result               |
  /// |---------|------------|----------------------|
  /// | pagi    | 1-11       | as said (jam 7 → 07) |
  /// | siang   | 11, 12     | as said (jam 12 → 12)|
  /// | siang   | 1-5        | +12 (jam 2 → 14)     |
  /// | sore    | 1-7        | +12 (jam 4 → 16)     |
  /// | malam   | 6-11       | +12 (jam 8 → 20)     |
  ///
  /// Not covered, so unclear: "jam 12 malam" (which day's midnight?) and
  /// "jam 1-5 malam" (late night or early morning?).
  static int? _modify(int hour, Daypart daypart) => switch (daypart) {
        Daypart.pagi when hour >= 1 && hour <= 11 => hour,
        Daypart.siang when hour == 11 || hour == 12 => hour,
        Daypart.siang when hour >= 1 && hour <= 5 => hour + 12,
        Daypart.sore when hour >= 1 && hour <= 7 => hour + 12,
        Daypart.malam when hour >= 6 && hour <= 11 => hour + 12,
        _ => null,
      };

  /// Calendar arithmetic, so a daylight-saving change can't shift the day.
  static DateTime _addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  /// The date, or null when it does not exist (DateTime would roll 31
  /// February over into March).
  static DateTime? _realDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    return date.month == month && date.day == day ? date : null;
  }
}
