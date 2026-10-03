import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/assistant_context.dart';

void main() {
  /// Saturday 3 October 2026, 10:00 local.
  final now = DateTime(2026, 10, 3, 10);

  test('a fixed clock gives a fixed context', () {
    final context = AssistantContext(now, utcOffset: const Duration(hours: 7));

    expect(context.now, now);
    expect(context.date, '2026-10-03');
    expect(context.time, '10:00');
    expect(context.weekday, 'saturday');
    expect(context.weekdayIndonesian, 'Sabtu');
    expect(context.utcOffsetLabel, '+07:00');
    expect(context.toJson(), {
      'date': '2026-10-03',
      'time': '10:00',
      'weekday': 'saturday',
      'weekday_id': 'Sabtu',
      'utc_offset': '+07:00',
    });
  });

  test('the same reading always gives an equal context', () {
    expect(AssistantContext(now), AssistantContext(now));
    expect(AssistantContext(now).toJson(), AssistantContext(now).toJson());
  });

  test('padding at the edges of the day and year', () {
    final context = AssistantContext(DateTime(2027, 1, 1, 0, 5),
        utcOffset: Duration.zero);

    expect(context.date, '2027-01-01');
    expect(context.time, '00:05');
    expect(context.weekday, 'friday');
    expect(context.weekdayIndonesian, 'Jumat');
    expect(context.utcOffsetLabel, '+00:00');
  });

  test('every weekday is named in both languages', () {
    final names = [
      for (var day = 5; day <= 11; day++)
        AssistantContext(DateTime(2026, 10, day)),
    ].map((c) => (c.weekday, c.weekdayIndonesian)).toList();

    expect(names, [
      ('monday', 'Senin'),
      ('tuesday', 'Selasa'),
      ('wednesday', 'Rabu'),
      ('thursday', 'Kamis'),
      ('friday', 'Jumat'),
      ('saturday', 'Sabtu'),
      ('sunday', 'Minggu'),
    ]);
  });

  test('UTC offsets, including half hours and negatives', () {
    String label(Duration offset) =>
        AssistantContext(now, utcOffset: offset).utcOffsetLabel;

    expect(label(const Duration(hours: 7)), '+07:00');
    expect(label(const Duration(hours: 5, minutes: 30)), '+05:30');
    expect(label(const Duration(hours: -3, minutes: -30)), '-03:30');
    expect(label(const Duration(hours: -10)), '-10:00');
  });

  test('the offset defaults to the device\'s for that moment', () {
    expect(AssistantContext(now).utcOffset, now.timeZoneOffset);
  });

  test('a UTC reading is turned into local time', () {
    final utc = DateTime.utc(2026, 10, 3, 3);
    final context = AssistantContext(utc);

    expect(context.now.isUtc, isFalse);
    expect(context.now, utc.toLocal());
  });
}
