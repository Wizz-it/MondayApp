import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/action_parser.dart';
import 'package:mondayapp/assistant/assistant_action.dart';

void main() {
  const parser = ActionParser();

  Matcher malformed() => isA<Unsupported>()
      .having((u) => u.kind, 'kind', UnsupportedKind.malformed);

  group('supported actions', () {
    test('create_task with every field', () {
      final action = parser.parse({
        'action': 'create_task',
        'title': 'belajar Flutter',
        'date': {'kind': 'tomorrow'},
        'time': {'hour': 7, 'minute': 30, 'daypart': 'pagi'},
        'project': 'MONDAY',
      });

      expect(
        action,
        const CreateTask(
          title: 'belajar Flutter',
          date: RelativeDateRef(RelativeDay.tomorrow),
          time: TimeRef(hour: 7, minute: 30, daypart: Daypart.pagi),
          project: 'MONDAY',
        ),
      );
    });

    test('create_task with only a title, nulls allowed', () {
      expect(
        parser.parse({
          'action': 'create_task',
          'title': 'Read',
          'date': null,
          'time': null,
          'project': null,
        }),
        const CreateTask(title: 'Read'),
      );
      expect(
        parser.parse({'action': 'create_task', 'title': 'Read'}),
        const CreateTask(title: 'Read'),
      );
    });

    test('create_event, with and without date and time', () {
      expect(
        parser.parse({
          'action': 'create_event',
          'title': 'meeting dengan dosen',
          'date': {'kind': 'weekday', 'weekday': 'friday', 'next_week': false},
          'time': {'hour': 2, 'minute': null, 'daypart': null},
          'description': 'Ruang 3',
        }),
        const CreateEvent(
          title: 'meeting dengan dosen',
          date: WeekdayDateRef(DateTime.friday),
          time: TimeRef(hour: 2),
          description: 'Ruang 3',
        ),
      );
      // Missing date and time reach the validator, which asks for them.
      expect(
        parser.parse({'action': 'create_event', 'title': 'Rapat'}),
        const CreateEvent(title: 'Rapat'),
      );
    });

    test('create_note, body optional', () {
      expect(
        parser.parse({
          'action': 'create_note',
          'title': 'Firebase',
          'body': 'nanti belajar Firebase',
        }),
        const CreateNote(title: 'Firebase', body: 'nanti belajar Firebase'),
      );
      expect(
        parser.parse({'action': 'create_note', 'title': 'Firebase'}),
        const CreateNote(title: 'Firebase'),
      );
    });

    test('capture_inbox', () {
      expect(
        parser.parse({'action': 'capture_inbox', 'text': 'cari internship'}),
        const CaptureInbox(text: 'cari internship'),
      );
    });

    test('query_agenda, duplicate parts collapse', () {
      expect(
        parser.parse({
          'action': 'query_agenda',
          'date': {'kind': 'today'},
          'include': ['tasks', 'events', 'tasks'],
        }),
        const QueryAgenda(
          date: RelativeDateRef(RelativeDay.today),
          include: {AgendaPart.tasks, AgendaPart.events},
        ),
      );
    });

    test('clarify', () {
      expect(
        parser.parse({'action': 'clarify', 'question': 'Jam berapa?'}),
        const Clarify(question: 'Jam berapa?'),
      );
    });

    test('unsupported from the model is a declined request', () {
      expect(
        parser.parse({'action': 'unsupported', 'reason': 'weather'}),
        const Unsupported(UnsupportedKind.declined, 'weather'),
      );
    });

    test('raw JSON text parses the same way', () {
      expect(
        parser.parseJson(
            '{"action":"capture_inbox","text":"cari internship Unity"}'),
        const CaptureInbox(text: 'cari internship Unity'),
      );
    });
  });

  group('date references', () {
    DateRef? dateOf(Map<String, Object?> date) {
      final action = parser.parse({
        'action': 'query_agenda',
        'date': date,
        'include': ['tasks'],
      });
      return action is QueryAgenda ? action.date : null;
    }

    test('relative days', () {
      expect(dateOf({'kind': 'today'}), const RelativeDateRef(RelativeDay.today));
      expect(dateOf({'kind': 'tomorrow'}),
          const RelativeDateRef(RelativeDay.tomorrow));
      expect(dateOf({'kind': 'day_after_tomorrow'}),
          const RelativeDateRef(RelativeDay.dayAfterTomorrow));
    });

    test('every weekday, and next week', () {
      const names = [
        'monday', 'tuesday', 'wednesday', 'thursday',
        'friday', 'saturday', 'sunday',
      ];
      for (final (i, name) in names.indexed) {
        expect(dateOf({'kind': 'weekday', 'weekday': name}),
            WeekdayDateRef(i + 1));
      }
      expect(dateOf({'kind': 'weekday', 'weekday': 'friday', 'next_week': true}),
          const WeekdayDateRef(DateTime.friday, nextWeek: true));
    });

    test('calendar dates, with and without a year', () {
      expect(dateOf({'kind': 'calendar_date', 'day': 12, 'month': 10}),
          const CalendarDateRef(day: 12, month: 10));
      expect(
          dateOf({
            'kind': 'calendar_date',
            'day': 12,
            'month': 10,
            'year': 2027,
            'weekday': null,
            'next_week': false,
          }),
          const CalendarDateRef(day: 12, month: 10, year: 2027));
    });

    test('impossible calendar values still parse; resolution rejects them', () {
      expect(dateOf({'kind': 'calendar_date', 'day': 31, 'month': 2}),
          const CalendarDateRef(day: 31, month: 2));
    });
  });

  group('time references', () {
    TimeRef? timeOf(Map<String, Object?> time) {
      final action =
          parser.parse({'action': 'create_task', 'title': 'x', 'time': time});
      return action is CreateTask ? action.time : null;
    }

    test('hour, minute and daypart are kept as said', () {
      expect(timeOf({'hour': 7, 'minute': 0, 'daypart': 'malam'}),
          const TimeRef(hour: 7, minute: 0, daypart: Daypart.malam));
      expect(timeOf({'hour': 14}), const TimeRef(hour: 14));
    });

    test('a daypart alone', () {
      for (final part in Daypart.values) {
        expect(timeOf({'daypart': part.name}), TimeRef(daypart: part));
      }
    });

    test('out-of-range values parse; resolution rejects them', () {
      expect(timeOf({'hour': 25, 'minute': 70}),
          const TimeRef(hour: 25, minute: 70));
    });
  });

  group('not supported', () {
    test('unknown action', () {
      expect(
        parser.parse({'action': 'order_pizza'}),
        const Unsupported(UnsupportedKind.unknownAction, 'order_pizza'),
      );
    });

    test('update, delete and complete are refused as destructive', () {
      for (final name in [
        'update_task',
        'delete_task',
        'complete_task',
        'update_event',
        'delete_event',
        'delete_project',
      ]) {
        expect(
          parser.parse({'action': name, 'id': 'task_1'}),
          Unsupported(UnsupportedKind.destructive, name),
          reason: name,
        );
      }
    });

    test('other queries are recognised but not offered yet', () {
      for (final name in ['query_projects', 'query_notes', 'query_inbox']) {
        expect(
          parser.parse({'action': name}),
          Unsupported(UnsupportedKind.notSupportedYet, name),
        );
      }
    });
  });

  group('malformed input', () {
    final cases = <String, Object?>{
      'null': null,
      'a list': [1, 2],
      'a string': 'create_task',
      'no action': {'title': 'x'},
      'non-string action': {'action': 7},
      'non-string keys': {1: 'x'},
      'missing title': {'action': 'create_task'},
      'title not a string': {'action': 'create_task', 'title': 7},
      'note body not a string': {
        'action': 'create_note',
        'title': 'x',
        'body': ['a'],
      },
      'missing inbox text': {'action': 'capture_inbox'},
      'missing question': {'action': 'clarify'},
      'missing unsupported reason': {'action': 'unsupported'},
      'id field': {'action': 'create_task', 'title': 'x', 'id': 'task_1'},
      'project id': {
        'action': 'create_task',
        'title': 'x',
        'project_id': 'project_monday',
      },
      'unexpected field': {'action': 'capture_inbox', 'text': 'x', 'due': 1},
      'project not a string': {'action': 'create_task', 'title': 'x', 'project': 1},
      'date not an object': {'action': 'create_task', 'title': 'x', 'date': 'besok'},
      'unknown date kind': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'yesterday'},
      },
      'missing date kind': {
        'action': 'create_task',
        'title': 'x',
        'date': {'weekday': 'friday'},
      },
      'unknown weekday': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'weekday', 'weekday': 'jumat'},
      },
      'weekday missing': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'weekday'},
      },
      'weekday with a day': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'weekday', 'weekday': 'friday', 'day': 3},
      },
      'today with a month': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'today', 'month': 10},
      },
      'next_week on a relative day': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'tomorrow', 'next_week': true},
      },
      'next_week not a bool': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'weekday', 'weekday': 'friday', 'next_week': 'yes'},
      },
      'calendar date without a month': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'calendar_date', 'day': 3},
      },
      'calendar date with a weekday': {
        'action': 'create_task',
        'title': 'x',
        'date': {
          'kind': 'calendar_date',
          'day': 3,
          'month': 10,
          'weekday': 'friday',
        },
      },
      'day as a string': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'calendar_date', 'day': '3', 'month': 10},
      },
      'unexpected date field': {
        'action': 'create_task',
        'title': 'x',
        'date': {'kind': 'today', 'iso': '2026-10-03'},
      },
      'time not an object': {'action': 'create_task', 'title': 'x', 'time': '07:00'},
      'hour as a decimal': {
        'action': 'create_task',
        'title': 'x',
        'time': {'hour': 7.0},
      },
      'hour as a string': {
        'action': 'create_task',
        'title': 'x',
        'time': {'hour': '7'},
      },
      'time with neither hour nor daypart': {
        'action': 'create_task',
        'title': 'x',
        'time': {'minute': 30},
      },
      'empty time': {
        'action': 'create_task',
        'title': 'x',
        'time': <String, Object?>{},
      },
      'unknown daypart': {
        'action': 'create_task',
        'title': 'x',
        'time': {'hour': 7, 'daypart': 'subuh'},
      },
      'unexpected time field': {
        'action': 'create_task',
        'title': 'x',
        'time': {'hour': 7, 'timezone': 'UTC'},
      },
      'query without a date': {
        'action': 'query_agenda',
        'include': ['tasks'],
      },
      'query include empty': {
        'action': 'query_agenda',
        'date': {'kind': 'today'},
        'include': <String>[],
      },
      'query include unknown part': {
        'action': 'query_agenda',
        'date': {'kind': 'today'},
        'include': ['notes'],
      },
      'query include not a list': {
        'action': 'query_agenda',
        'date': {'kind': 'today'},
        'include': 'tasks',
      },
    };

    for (final MapEntry(key: name, value: input) in cases.entries) {
      test(name, () => expect(parser.parse(input), malformed()));
    }

    test('text that is not JSON', () {
      expect(parser.parseJson('{"action": "create_task", '), malformed());
      expect(parser.parseJson(''), malformed());
      expect(parser.parseJson('Sure! Here is the JSON:'), malformed());
    });

    test('nothing ever throws', () {
      final inputs = <Object?>[
        ...cases.values,
        double.nan,
        {'action': 'create_task', 'title': 'x', 'date': {'kind': null}},
        {'action': 'create_event', 'title': 'x', 'time': [7]},
        {'action': 'query_agenda', 'date': {'kind': 'today'}, 'include': [null]},
        {
          'action': 'create_task',
          'title': 'x',
          'date': {'kind': 'calendar_date', 'day': 1 << 40, 'month': -3},
        },
      ];
      for (final input in inputs) {
        expect(() => parser.parse(input), returnsNormally);
      }
      for (final text in ['', '[', 'null', '"x"', '1', '{"action":null}']) {
        expect(() => parser.parseJson(text), returnsNormally);
      }
    });
  });
}
