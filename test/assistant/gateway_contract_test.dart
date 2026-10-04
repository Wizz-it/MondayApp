import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/action_parser.dart';
import 'package:mondayapp/assistant/assistant_action.dart';

/// The gateway's contract fixtures, shared with the Functions tests in
/// `functions/test/fixtures.test.ts`. Every response the gateway can produce
/// must parse into the action it names — the Dart parser is the authority.
void main() {
  const parser = ActionParser();
  final fixtures = Directory('contract/assistant')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  Map<String, Object?> load(File file) =>
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

  test('the shared fixtures are present', () {
    expect(fixtures, isNotEmpty);
  });

  final expectedType = <String, TypeMatcher<AssistantAction>>{
    'create_task': isA<CreateTask>(),
    'create_event': isA<CreateEvent>(),
    'create_note': isA<CreateNote>(),
    'capture_inbox': isA<CaptureInbox>(),
    'query_agenda': isA<QueryAgenda>(),
    'clarify': isA<Clarify>(),
    'unsupported': isA<Unsupported>()
        .having((u) => u.kind, 'kind', UnsupportedKind.declined),
  };

  for (final file in fixtures) {
    final name = file.uri.pathSegments.last;

    test('$name parses into the action it names', () {
      final response = load(file)['response'] as Map<String, Object?>;
      expect(response['v'], 1);
      final action = response['action'] as Map<String, Object?>;

      final parsed = parser.parse(action);

      expect(parsed, expectedType[action['action']], reason: '$parsed');
    });

    test('$name survives the trip through JSON text', () {
      final action =
          (load(file)['response'] as Map<String, Object?>)['action'];

      // What a GatewayAIService would hand the parser.
      expect(parser.parseJson(jsonEncode(action)), parser.parse(action));
    });
  }

  test('the task fixture means "besok jam 7, belajar Flutter"', () {
    final file = fixtures.singleWhere((f) => f.path.endsWith('create_task.json'));
    final action = (load(file)['response'] as Map<String, Object?>)['action'];

    expect(
      parser.parse(action),
      const CreateTask(
        title: 'Belajar Flutter',
        date: RelativeDateRef(RelativeDay.tomorrow),
        time: TimeRef(hour: 7, minute: 0),
      ),
    );
  });

  test('the minimal fixture, with optional fields left out, parses too', () {
    final file =
        fixtures.singleWhere((f) => f.path.endsWith('create_task_minimal.json'));
    final action = (load(file)['response'] as Map<String, Object?>)['action'];

    expect(
      parser.parse(action),
      const CreateTask(
        title: 'Rapat proyek',
        date: CalendarDateRef(day: 12, month: 10, year: 2026),
        time: TimeRef(daypart: Daypart.malam),
        project: 'MONDAY',
      ),
    );
  });
}
