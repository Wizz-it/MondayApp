import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/action_validator.dart';
import 'package:mondayapp/assistant/assistant_action.dart';
import 'package:mondayapp/assistant/date_resolver.dart';
import 'package:mondayapp/services/app_store.dart';

/// Saturday 3 October 2026, 10:00 local.
final now = DateTime(2026, 10, 3, 10);

const tomorrow = RelativeDateRef(RelativeDay.tomorrow);
const today = RelativeDateRef(RelativeDay.today);

void main() {
  late AppStore store;
  late ActionValidator validator;

  setUp(() {
    store = AppStore(seedDate: now);
    validator = ActionValidator(store, clock: () => now);
  });

  T expectResult<T extends ValidationResult>(AssistantAction action) {
    final result = validator.validate(action);
    expect(result, isA<T>(), reason: '$action');
    return result as T;
  }

  ResolvedTask readyTask(CreateTask action) =>
      expectResult<Ready>(action).action as ResolvedTask;

  ResolvedEvent readyEvent(CreateEvent action) =>
      expectResult<Ready>(action).action as ResolvedEvent;

  RejectionReason rejected(AssistantAction action) =>
      expectResult<Rejected>(action).reason;

  group('tasks', () {
    test('empty and whitespace-only titles are rejected', () {
      expect(rejected(const CreateTask(title: '')), RejectionReason.emptyTitle);
      expect(rejected(const CreateTask(title: '   \n ')),
          RejectionReason.emptyTitle);
    });

    test('the title is trimmed, as the form does', () {
      expect(readyTask(const CreateTask(title: '  Belajar Flutter ')).title,
          'Belajar Flutter');
    });

    test('no date and no time: an undated task', () {
      final task = readyTask(const CreateTask(title: 'Read'));
      expect(task.dueDate, isNull);
      expect(task.reminder, isNull);
    });

    test('a date alone sets the due day only', () {
      final task = readyTask(const CreateTask(title: 'Read', date: tomorrow));
      expect(task.dueDate, DateTime(2026, 10, 4));
      expect(task.reminder, isNull);
    });

    test('a time becomes a reminder on the due day', () {
      final task = readyTask(const CreateTask(
        title: 'Belajar Flutter',
        date: tomorrow,
        time: TimeRef(hour: 7, daypart: Daypart.pagi),
      ));
      expect(task.dueDate, DateTime(2026, 10, 4));
      expect(task.reminder, DateTime(2026, 10, 4, 7));
    });

    test('a time without a date means today', () {
      final task =
          readyTask(const CreateTask(title: 'Call', time: TimeRef(hour: 15)));
      expect(task.dueDate, DateTime(2026, 10, 3));
      expect(task.reminder, DateTime(2026, 10, 3, 15));
    });

    test('"besok jam 7" is ready at 07:00, no confirmation', () {
      final task = readyTask(const CreateTask(
        title: 'Belajar Flutter',
        date: tomorrow,
        time: TimeRef(hour: 7),
      ));
      expect(task.dueDate, DateTime(2026, 10, 4));
      expect(task.reminder, DateTime(2026, 10, 4, 7));
    });

    test('"jam 8 malam" is ready at 20:00', () {
      expect(
        readyTask(const CreateTask(
          title: 'x',
          date: tomorrow,
          time: TimeRef(hour: 8, daypart: Daypart.malam),
        )).reminder,
        DateTime(2026, 10, 4, 20),
      );
    });

    test('"jam 2" alone asks which, and offers nothing to execute', () {
      final result = expectResult<NeedsClarification>(const CreateTask(
        title: 'Belajar Flutter',
        date: tomorrow,
        time: TimeRef(hour: 2),
      ));
      expect(result.reason, ClarificationReason.ambiguousTime);
      expect(result.timeOptions, const [ClockTime(2, 0), ClockTime(14, 0)]);
    });

    test('a time already passed today needs confirmation', () {
      final result = expectResult<NeedsConfirmation>(const CreateTask(
        title: 'Late',
        date: today,
        time: TimeRef(hour: 9, daypart: Daypart.pagi),
      ));
      expect(result.reasons, [ConfirmationReason.pastTime]);
      expect((result.action as ResolvedTask).reminder,
          DateTime(2026, 10, 3, 9));
    });

    test('a day in the past needs confirmation', () {
      final result = expectResult<NeedsConfirmation>(const CreateTask(
        title: 'Old',
        date: CalendarDateRef(day: 1, month: 1, year: 2025),
      ));
      expect(result.reasons, [ConfirmationReason.pastDay]);
    });

    test('an impossible date is rejected', () {
      expect(
        rejected(const CreateTask(
          title: 'x',
          date: CalendarDateRef(day: 31, month: 2),
        )),
        RejectionReason.invalidDate,
      );
    });

    test('an impossible hour or minute is rejected', () {
      expect(
        rejected(const CreateTask(title: 'x', time: TimeRef(hour: 25))),
        RejectionReason.invalidTime,
      );
      expect(
        rejected(
            const CreateTask(title: 'x', time: TimeRef(hour: 7, minute: 60))),
        RejectionReason.invalidTime,
      );
    });

    test('an hour that contradicts the part of the day asks again', () {
      final result = expectResult<NeedsClarification>(const CreateTask(
        title: 'x',
        time: TimeRef(hour: 3, daypart: Daypart.malam),
      ));
      expect(result.reason, ClarificationReason.unclearTime);
    });
  });

  group('projects', () {
    test('an exact name matches, and the id comes from the store', () {
      final task = readyTask(const CreateTask(title: 'x', project: 'MONDAY'));
      expect(task.projectId, 'project_monday');
      expect(task.projectName, 'MONDAY');
      expect(task.unmatchedProject, isNull);
    });

    test('matching ignores case and surrounding spaces', () {
      expect(readyTask(const CreateTask(title: 'x', project: 'monday'))
          .projectId, 'project_monday');
      expect(readyTask(const CreateTask(title: 'x', project: '  pORTFOLIO '))
          .projectId, 'project_portfolio');
    });

    NeedsConfirmation unknown(CreateTask action) {
      final result = expectResult<NeedsConfirmation>(action);
      expect(result.reasons, contains(ConfirmationReason.unknownProject));
      return result;
    }

    test('an unknown project asks before creating the task without one', () {
      final before = store.projects.length;

      final result = unknown(const CreateTask(
        title: 'Siram tanaman',
        date: tomorrow,
        project: ' Garden ',
      ));

      expect(result.reasons, [ConfirmationReason.unknownProject]);
      final task = result.action as ResolvedTask;
      expect(task.title, 'Siram tanaman');
      expect(task.dueDate, DateTime(2026, 10, 4));
      expect(task.projectId, isNull);
      expect(task.projectName, isNull);
      expect(task.unmatchedProject, 'Garden');
      // Never created, not even a placeholder.
      expect(store.projects, hasLength(before));
    });

    test('a partial name does not match', () {
      final task = unknown(const CreateTask(title: 'x', project: 'Port'))
          .action as ResolvedTask;
      expect(task.unmatchedProject, 'Port');
    });

    test('an unknown project and a passed time are asked together', () {
      final result = unknown(const CreateTask(
        title: 'x',
        date: today,
        time: TimeRef(hour: 8, daypart: Daypart.pagi),
        project: 'Garden',
      ));
      expect(result.reasons,
          [ConfirmationReason.unknownProject, ConfirmationReason.pastTime]);
    });

    test('a blank project name is the same as none', () {
      final task = readyTask(const CreateTask(title: 'x', project: '  '));
      expect(task.projectId, isNull);
      expect(task.unmatchedProject, isNull);
    });
  });

  group('events', () {
    test('a dated, timed event is ready', () {
      final event = readyEvent(const CreateEvent(
        title: ' meeting dengan dosen ',
        date: WeekdayDateRef(DateTime.friday),
        time: TimeRef(hour: 2, daypart: Daypart.siang),
        description: '  Ruang 3 ',
      ));
      expect(event.title, 'meeting dengan dosen');
      expect(event.start, DateTime(2026, 10, 9, 14));
      expect(event.description, 'Ruang 3');
    });

    test('a missing description becomes empty', () {
      final event = readyEvent(const CreateEvent(
        title: 'x',
        date: tomorrow,
        time: TimeRef(hour: 13),
      ));
      expect(event.description, '');
    });

    test('empty title is rejected', () {
      expect(
        rejected(const CreateEvent(
            title: ' ', date: tomorrow, time: TimeRef(hour: 13))),
        RejectionReason.emptyTitle,
      );
    });

    test('a missing date asks for the day', () {
      final result = expectResult<NeedsClarification>(
          const CreateEvent(title: 'Rapat', time: TimeRef(hour: 13)));
      expect(result.reason, ClarificationReason.missingEventDate);
    });

    test('a missing time asks for the time', () {
      final result = expectResult<NeedsClarification>(
          const CreateEvent(title: 'Rapat', date: tomorrow));
      expect(result.reason, ClarificationReason.missingEventTime);
    });

    test('a part of the day is enough of a time', () {
      expect(
        readyEvent(const CreateEvent(
          title: 'Lari',
          date: tomorrow,
          time: TimeRef(daypart: Daypart.pagi),
        )).start,
        DateTime(2026, 10, 4, 8),
      );
    });

    test('"Jumat jam 2" asks which 2', () {
      final result = expectResult<NeedsClarification>(const CreateEvent(
        title: 'meeting dengan dosen',
        date: WeekdayDateRef(DateTime.friday),
        time: TimeRef(hour: 2),
      ));
      expect(result.reason, ClarificationReason.ambiguousTime);
      expect(result.timeOptions, const [ClockTime(2, 0), ClockTime(14, 0)]);
    });

    test('"Jumat jam 2 siang" is ready', () {
      expect(
        readyEvent(const CreateEvent(
          title: 'meeting dengan dosen',
          date: WeekdayDateRef(DateTime.friday),
          time: TimeRef(hour: 2, daypart: Daypart.siang),
        )).start,
        DateTime(2026, 10, 9, 14),
      );
    });

    test('"jam 4 sore" and "jam 8 malam" are ready', () {
      expect(
        readyEvent(const CreateEvent(
          title: 'x',
          date: tomorrow,
          time: TimeRef(hour: 4, daypart: Daypart.sore),
        )).start,
        DateTime(2026, 10, 4, 16),
      );
      expect(
        readyEvent(const CreateEvent(
          title: 'x',
          date: tomorrow,
          time: TimeRef(hour: 8, daypart: Daypart.malam),
        )).start,
        DateTime(2026, 10, 4, 20),
      );
    });

    test('today with a passed time needs confirmation', () {
      final result = expectResult<NeedsConfirmation>(const CreateEvent(
        title: 'x',
        date: today,
        time: TimeRef(hour: 8, daypart: Daypart.pagi),
      ));
      expect(result.reasons, [ConfirmationReason.pastTime]);
      expect((result.action as ResolvedEvent).start, DateTime(2026, 10, 3, 8));
    });

    test('this weekday with a passed time moves to next week instead', () {
      final event = readyEvent(const CreateEvent(
        title: 'x',
        date: WeekdayDateRef(DateTime.saturday),
        time: TimeRef(hour: 9, daypart: Daypart.pagi),
      ));
      expect(event.start, DateTime(2026, 10, 10, 9));
    });

    test('an impossible date is rejected', () {
      expect(
        rejected(const CreateEvent(
          title: 'x',
          date: CalendarDateRef(day: 31, month: 4),
          time: TimeRef(hour: 13),
        )),
        RejectionReason.invalidDate,
      );
    });
  });

  group('notes and inbox', () {
    test('a note needs a title; the body may be empty', () {
      expect(rejected(const CreateNote(title: '  ')), RejectionReason.emptyTitle);
      final note = expectResult<Ready>(
              const CreateNote(title: ' Firebase ', body: '  '))
          .action as ResolvedNote;
      expect(note.title, 'Firebase');
      expect(note.body, '');
    });

    test('inbox text is trimmed and must not be empty', () {
      expect(rejected(const CaptureInbox(text: '')), RejectionReason.emptyText);
      expect(rejected(const CaptureInbox(text: ' \t ')),
          RejectionReason.emptyText);
      expect(
        expectResult<Ready>(const CaptureInbox(text: ' cari internship '))
            .action,
        const ResolvedInboxCapture('cari internship'),
      );
    });
  });

  group('queries', () {
    test('resolve to a day and keep what to include', () {
      expect(
        expectResult<Ready>(const QueryAgenda(
          date: tomorrow,
          include: {AgendaPart.tasks},
        )).action,
        ResolvedAgendaQuery(
          day: DateTime(2026, 10, 4),
          include: const {AgendaPart.tasks},
        ),
      );
    });

    test('an impossible date is rejected', () {
      expect(
        rejected(const QueryAgenda(
          date: CalendarDateRef(day: 30, month: 2),
          include: {AgendaPart.tasks},
        )),
        RejectionReason.invalidDate,
      );
    });
  });

  group('clarify and unsupported', () {
    test('the model\'s question is passed on', () {
      final result =
          expectResult<NeedsClarification>(const Clarify(question: 'Kapan?'));
      expect(result.reason, ClarificationReason.askedByAssistant);
      expect(result.question, 'Kapan?');
    });

    test('each kind of unsupported request maps to a rejection', () {
      final expected = {
        UnsupportedKind.declined: RejectionReason.outOfScope,
        UnsupportedKind.destructive: RejectionReason.destructive,
        UnsupportedKind.notSupportedYet: RejectionReason.notSupportedYet,
        UnsupportedKind.unknownAction: RejectionReason.notUnderstood,
        UnsupportedKind.malformed: RejectionReason.notUnderstood,
      };
      for (final MapEntry(key: kind, value: reason) in expected.entries) {
        expect(rejected(Unsupported(kind, 'x')), reason, reason: '$kind');
      }
    });
  });

  test('validation never writes to the store', () {
    var notified = 0;
    store.addListener(() => notified++);
    final before = jsonEncode(store.toJson());

    for (final action in const <AssistantAction>[
      CreateTask(title: 'a', date: tomorrow, time: TimeRef(hour: 7)),
      CreateTask(title: 'b', project: 'Garden'),
      CreateEvent(title: 'c', date: tomorrow, time: TimeRef(hour: 13)),
      CreateNote(title: 'd'),
      CaptureInbox(text: 'e'),
      QueryAgenda(date: today, include: {AgendaPart.tasks, AgendaPart.events}),
      Clarify(question: 'f'),
      Unsupported(UnsupportedKind.destructive, 'delete_task'),
    ]) {
      validator.validate(action);
    }

    expect(notified, 0);
    expect(jsonEncode(store.toJson()), before);
  });

  test('the clock is read once per validation', () {
    var reads = 0;
    final counting = ActionValidator(store, clock: () {
      reads++;
      return now;
    });

    counting.validate(const CreateEvent(
      title: 'x',
      date: WeekdayDateRef(DateTime.friday),
      time: TimeRef(hour: 2),
    ));

    expect(reads, 1);
  });
}
