import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/assistant_action.dart';
import 'package:mondayapp/assistant/date_resolver.dart';

/// Saturday 3 October 2026, 10:00 local.
final saturday = DateTime(2026, 10, 3, 10);

DateTime day(DateResolver resolver, DateRef ref, {ClockTime? at}) {
  final result = resolver.resolveDay(ref, at: at);
  expect(result, isA<ResolvedDay>(), reason: '$ref');
  return (result as ResolvedDay).day;
}

TimeResolution time(int? hour, {int? minute, Daypart? daypart}) =>
    DateResolver(saturday)
        .resolveTime(TimeRef(hour: hour, minute: minute, daypart: daypart));

Matcher exact(int hour, [int minute = 0]) => isA<ExactTime>()
    .having((t) => t.time, 'time', ClockTime(hour, minute));

void main() {
  test('the fixed clock really is a Saturday', () {
    expect(saturday.weekday, DateTime.saturday);
  });

  group('relative days', () {
    final resolver = DateResolver(saturday);

    test('today, tomorrow and the day after', () {
      expect(day(resolver, const RelativeDateRef(RelativeDay.today)),
          DateTime(2026, 10, 3));
      expect(day(resolver, const RelativeDateRef(RelativeDay.tomorrow)),
          DateTime(2026, 10, 4));
      expect(day(resolver, const RelativeDateRef(RelativeDay.dayAfterTomorrow)),
          DateTime(2026, 10, 5));
    });

    test('results are local midnight, never UTC', () {
      final result = day(resolver, const RelativeDateRef(RelativeDay.tomorrow));
      expect(result.isUtc, isFalse);
      expect((result.hour, result.minute, result.second), (0, 0, 0));
    });

    test('across a month end', () {
      final resolver = DateResolver(DateTime(2026, 10, 31, 22));
      expect(day(resolver, const RelativeDateRef(RelativeDay.tomorrow)),
          DateTime(2026, 11, 1));
      expect(day(resolver, const RelativeDateRef(RelativeDay.dayAfterTomorrow)),
          DateTime(2026, 11, 2));
    });

    test('across a year end', () {
      final resolver = DateResolver(DateTime(2026, 12, 31, 23, 59));
      expect(day(resolver, const RelativeDateRef(RelativeDay.today)),
          DateTime(2026, 12, 31));
      expect(day(resolver, const RelativeDateRef(RelativeDay.tomorrow)),
          DateTime(2027, 1, 1));
      expect(day(resolver, const RelativeDateRef(RelativeDay.dayAfterTomorrow)),
          DateTime(2027, 1, 2));
    });

    test('into 29 February in a leap year, and past it otherwise', () {
      expect(
          day(DateResolver(DateTime(2028, 2, 28)),
              const RelativeDateRef(RelativeDay.tomorrow)),
          DateTime(2028, 2, 29));
      expect(
          day(DateResolver(DateTime(2027, 2, 28)),
              const RelativeDateRef(RelativeDay.tomorrow)),
          DateTime(2027, 3, 1));
    });
  });

  group('weekdays', () {
    final resolver = DateResolver(saturday);

    test('each weekday is its next occurrence, today included', () {
      final expected = {
        DateTime.monday: DateTime(2026, 10, 5),
        DateTime.tuesday: DateTime(2026, 10, 6),
        DateTime.wednesday: DateTime(2026, 10, 7),
        DateTime.thursday: DateTime(2026, 10, 8),
        DateTime.friday: DateTime(2026, 10, 9),
        DateTime.saturday: DateTime(2026, 10, 3),
        DateTime.sunday: DateTime(2026, 10, 4),
      };
      for (final MapEntry(key: weekday, value: date) in expected.entries) {
        final resolved = day(resolver, WeekdayDateRef(weekday));
        expect(resolved, date, reason: 'weekday $weekday');
        expect(resolved.weekday, weekday);
      }
    });

    test('today with a time still ahead stays today', () {
      expect(
        day(resolver, const WeekdayDateRef(DateTime.saturday),
            at: const ClockTime(15, 0)),
        DateTime(2026, 10, 3),
      );
    });

    test('today at exactly now stays today', () {
      expect(
        day(resolver, const WeekdayDateRef(DateTime.saturday),
            at: const ClockTime(10, 0)),
        DateTime(2026, 10, 3),
      );
    });

    test('today with a time already passed moves to next week', () {
      expect(
        day(resolver, const WeekdayDateRef(DateTime.saturday),
            at: const ClockTime(9, 0)),
        DateTime(2026, 10, 10),
      );
    });

    test('a passed time only matters when the weekday is today', () {
      expect(
        day(resolver, const WeekdayDateRef(DateTime.sunday),
            at: const ClockTime(9, 0)),
        DateTime(2026, 10, 4),
      );
    });

    test('next week means the following Monday-to-Sunday week', () {
      // From Saturday the 3rd, next week runs Monday 5th to Sunday 11th.
      expect(
          day(resolver,
              const WeekdayDateRef(DateTime.monday, nextWeek: true)),
          DateTime(2026, 10, 5));
      expect(
          day(resolver,
              const WeekdayDateRef(DateTime.friday, nextWeek: true)),
          DateTime(2026, 10, 9));
      expect(
          day(resolver,
              const WeekdayDateRef(DateTime.saturday, nextWeek: true)),
          DateTime(2026, 10, 10));

      // From Wednesday the 7th, "Jumat depan" skips this week's Friday.
      final wednesday = DateResolver(DateTime(2026, 10, 7, 9));
      expect(
          day(wednesday,
              const WeekdayDateRef(DateTime.friday, nextWeek: true)),
          DateTime(2026, 10, 16));
      expect(day(wednesday, const WeekdayDateRef(DateTime.friday)),
          DateTime(2026, 10, 9));
    });

    test('across a year end', () {
      // Thursday 31 December 2026.
      final resolver = DateResolver(DateTime(2026, 12, 31, 12));
      expect(day(resolver, const WeekdayDateRef(DateTime.monday)),
          DateTime(2027, 1, 4));
    });
  });

  group('calendar dates', () {
    final resolver = DateResolver(saturday);

    test('later this year', () {
      expect(day(resolver, const CalendarDateRef(day: 12, month: 10)),
          DateTime(2026, 10, 12));
    });

    test('today is not in the past', () {
      expect(day(resolver, const CalendarDateRef(day: 3, month: 10)),
          DateTime(2026, 10, 3));
    });

    test('already passed this year means next year', () {
      expect(day(resolver, const CalendarDateRef(day: 2, month: 10)),
          DateTime(2027, 10, 2));
      expect(day(resolver, const CalendarDateRef(day: 1, month: 1)),
          DateTime(2027, 1, 1));
    });

    test('an explicit year is taken as said, even in the past', () {
      expect(
          day(resolver, const CalendarDateRef(day: 12, month: 10, year: 2027)),
          DateTime(2027, 10, 12));
      expect(
          day(resolver, const CalendarDateRef(day: 1, month: 1, year: 2025)),
          DateTime(2025, 1, 1));
    });

    test('29 February finds the next leap year', () {
      expect(day(resolver, const CalendarDateRef(day: 29, month: 2)),
          DateTime(2028, 2, 29));
      expect(
          day(resolver, const CalendarDateRef(day: 29, month: 2, year: 2028)),
          DateTime(2028, 2, 29));
    });

    test('dates that do not exist are invalid', () {
      for (final ref in const [
        CalendarDateRef(day: 31, month: 2),
        CalendarDateRef(day: 30, month: 2),
        CalendarDateRef(day: 31, month: 4),
        CalendarDateRef(day: 29, month: 2, year: 2027),
        CalendarDateRef(day: 0, month: 10),
        CalendarDateRef(day: 32, month: 10),
        CalendarDateRef(day: 1, month: 13),
        CalendarDateRef(day: 1, month: 0),
      ]) {
        expect(resolver.resolveDay(ref), isA<InvalidDay>(), reason: '$ref');
      }
    });
  });

  group('times', () {
    test('explicit 24-hour times are kept exactly', () {
      expect(time(13, minute: 45), exact(13, 45));
      expect(time(0, minute: 15), exact(0, 15));
      expect(time(23, minute: 59), exact(23, 59));
    });

    test('"besok jam 7": ordinary hours without a part of the day are taken '
        'as said', () {
      expect(time(7), exact(7));
      for (var hour = 7; hour <= 11; hour++) {
        expect(time(hour), exact(hour), reason: 'jam $hour');
      }
      expect(time(12), exact(12), reason: 'jam 12 is noon');
    });

    test('the part of the day modifies the spoken hour', () {
      expect(time(7, daypart: Daypart.pagi), exact(7));
      expect(time(2, daypart: Daypart.siang), exact(14));
      expect(time(4, daypart: Daypart.sore), exact(16));
      expect(time(8, daypart: Daypart.malam), exact(20));
    });

    test('pagi keeps the hour', () {
      expect(time(5, daypart: Daypart.pagi), exact(5));
      expect(time(11, daypart: Daypart.pagi), exact(11));
    });

    test('siang keeps 11 and 12 and moves 1 to 5 to the afternoon', () {
      expect(time(11, daypart: Daypart.siang), exact(11));
      expect(time(12, daypart: Daypart.siang), exact(12));
      expect(time(1, daypart: Daypart.siang), exact(13));
      expect(time(5, daypart: Daypart.siang), exact(17));
    });

    test('sore moves 1 to 7 to the afternoon', () {
      expect(time(1, daypart: Daypart.sore), exact(13));
      expect(time(6, daypart: Daypart.sore), exact(18));
      expect(time(7, daypart: Daypart.sore), exact(19));
    });

    test('malam moves 6 to 11 to the evening', () {
      expect(time(6, daypart: Daypart.malam), exact(18));
      expect(time(7, daypart: Daypart.malam), exact(19));
      expect(time(11, daypart: Daypart.malam), exact(23));
    });

    test('a 24-hour hour that agrees with the part of the day is kept', () {
      expect(time(19, daypart: Daypart.malam), exact(19));
      expect(time(14, daypart: Daypart.siang), exact(14));
      expect(time(16, daypart: Daypart.sore), exact(16));
    });

    test('minutes are preserved', () {
      expect(time(7, minute: 30, daypart: Daypart.malam), exact(19, 30));
      expect(time(7, minute: 5), exact(7, 5));
      expect(
        time(2, minute: 15),
        isA<AmbiguousTime>().having((t) => t.readings, 'readings',
            const [ClockTime(2, 15), ClockTime(14, 15)]),
      );
    });

    test('a part of the day alone uses the documented default', () {
      expect(time(null, daypart: Daypart.pagi), exact(8));
      expect(time(null, daypart: Daypart.siang), exact(12));
      expect(time(null, daypart: Daypart.sore), exact(16));
      expect(time(null, daypart: Daypart.malam), exact(19));
    });

    test('"jam 2" alone is ambiguous, not silently afternoon', () {
      expect(
        time(2),
        isA<AmbiguousTime>().having((t) => t.readings, 'readings',
            const [ClockTime(2, 0), ClockTime(14, 0)]),
      );
    });

    test('every hour from 1 to 6 alone is ambiguous', () {
      for (var hour = 1; hour <= 6; hour++) {
        expect(
          time(hour),
          isA<AmbiguousTime>().having((t) => t.readings, 'readings',
              [ClockTime(hour, 0), ClockTime(hour + 12, 0)]),
          reason: 'jam $hour',
        );
      }
    });

    test('a part of the day that cannot describe the hour is unclear', () {
      expect(time(9, daypart: Daypart.sore), isA<UnclearTime>());
      expect(time(8, daypart: Daypart.siang), isA<UnclearTime>());
      expect(time(12, daypart: Daypart.pagi), isA<UnclearTime>());
      expect(time(12, daypart: Daypart.malam), isA<UnclearTime>(),
          reason: 'which midnight?');
      expect(time(3, daypart: Daypart.malam), isA<UnclearTime>(),
          reason: 'late night or early morning?');
      expect(time(0, daypart: Daypart.pagi), isA<UnclearTime>());
      expect(time(19, daypart: Daypart.pagi), isA<UnclearTime>());
      expect(time(14, daypart: Daypart.malam), isA<UnclearTime>());
    });

    test('impossible times are invalid', () {
      expect(time(24), isA<InvalidTime>());
      expect(time(-1), isA<InvalidTime>());
      expect(time(7, minute: 60), isA<InvalidTime>());
      expect(time(7, minute: -5), isA<InvalidTime>());
      expect(time(null), isA<InvalidTime>());
    });
  });

  test('ClockTime places a time on a local day', () {
    final at = const ClockTime(7, 30).on(DateTime(2026, 10, 4));
    expect(at, DateTime(2026, 10, 4, 7, 30));
    expect(at.isUtc, isFalse);
  });
}
