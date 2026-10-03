import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/action_executor.dart';
import 'package:mondayapp/assistant/action_validator.dart';
import 'package:mondayapp/assistant/agenda_query.dart';
import 'package:mondayapp/assistant/assistant_action.dart';
import 'package:mondayapp/assistant/date_resolver.dart';
import 'package:mondayapp/assistant/response_composer.dart';

/// Saturday 3 October 2026, 10:00 local.
final now = DateTime(2026, 10, 3, 10);
final composer = ResponseComposer(now);

const both = {AgendaPart.tasks, AgendaPart.events};

AgendaSnapshot agenda({
  DateTime? day,
  Set<AgendaPart> include = both,
  List<String> tasks = const [],
  int completed = 0,
  Map<String, DateTime> events = const {},
}) {
  return AgendaSnapshot(
    day: day ?? DateTime(2026, 10, 3),
    include: include,
    openTasks: [for (final t in tasks) AgendaTask(title: t)],
    completedTaskCount: completed,
    events: [
      for (final MapEntry(:key, :value) in events.entries)
        AgendaEvent(title: key, start: value),
    ],
  );
}

String answer(AgendaSnapshot snapshot) =>
    composer.executed(AgendaAnswered(snapshot));

void main() {
  group('created items', () {
    test('task with a due day', () {
      expect(
        composer.executed(TaskCreated(
          taskId: 'task_9',
          title: 'Belajar Flutter',
          dueDate: DateTime(2026, 10, 4),
        )),
        'Task Belajar Flutter ditambahkan untuk 4 Oktober.',
      );
    });

    test('task with a reminder', () {
      expect(
        composer.executed(TaskCreated(
          taskId: 'task_9',
          title: 'Belajar Flutter',
          dueDate: DateTime(2026, 10, 4),
          reminder: DateTime(2026, 10, 4, 7),
        )),
        'Task Belajar Flutter ditambahkan untuk 4 Oktober, '
        'dengan pengingat pukul 07.00.',
      );
    });

    test('task without a date', () {
      expect(
        composer.executed(
            const TaskCreated(taskId: 'task_9', title: 'Belajar Flutter')),
        'Task Belajar Flutter ditambahkan.',
      );
    });

    test('task in a project', () {
      expect(
        composer.executed(TaskCreated(
          taskId: 'task_9',
          title: 'Review',
          dueDate: DateTime(2026, 10, 4),
          projectName: 'MONDAY',
        )),
        'Task Review ditambahkan ke proyek MONDAY untuk 4 Oktober.',
      );
    });

    test('task created without its unknown project, after confirmation', () {
      expect(
        composer.executed(TaskCreated(
          taskId: 'task_9',
          title: 'Siram tanaman',
          dueDate: DateTime(2026, 10, 4),
          unmatchedProject: 'Garden',
        )),
        'Task Siram tanaman ditambahkan tanpa proyek untuk 4 Oktober.',
      );
    });

    test('dates outside this year carry the year', () {
      expect(
        composer.executed(TaskCreated(
          taskId: 'task_9',
          title: 'Tahun baru',
          dueDate: DateTime(2027, 1, 4),
        )),
        'Task Tahun baru ditambahkan untuk 4 Januari 2027.',
      );
    });

    test('event', () {
      expect(
        composer.executed(EventCreated(
          eventId: 'event_9',
          title: 'Meeting dengan dosen',
          start: DateTime(2026, 10, 9, 14),
        )),
        'Event Meeting dengan dosen dijadwalkan pada 9 Oktober pukul 14.00.',
      );
    });

    test('note', () {
      expect(
        composer.executed(
            const NoteCreated(noteId: 'note_9', title: 'Firebase')),
        'Catatan Firebase disimpan.',
      );
    });

    test('inbox', () {
      expect(
        composer.executed(
            const InboxCaptured(itemId: 'inbox_9', text: 'cari internship')),
        'Sudah dicatat ke Inbox.',
      );
    });
  });

  group('agenda', () {
    test('tasks and events today', () {
      expect(
        answer(agenda(
          tasks: ['Review', 'Kirim update'],
          events: {'Project check-in': DateTime(2026, 10, 3, 14, 30)},
        )),
        'Hari ini ada 2 task dan 1 event. Task: Review, Kirim update. '
        'Event: Project check-in pukul 14.30.',
      );
    });

    test('starts with the count sentence', () {
      expect(
        answer(agenda(
          tasks: ['A', 'B'],
          events: {'C': DateTime(2026, 10, 3, 9)},
        )),
        startsWith('Hari ini ada 2 task dan 1 event.'),
      );
    });

    test('nothing at all', () {
      expect(answer(agenda()), 'Hari ini tidak ada task atau event.');
    });

    test('tasks but no events, and the other way round', () {
      expect(answer(agenda(tasks: ['A'])),
          'Hari ini ada 1 task dan tidak ada event. Task: A.');
      expect(answer(agenda(events: {'B': DateTime(2026, 10, 3, 16)})),
          'Hari ini tidak ada task dan ada 1 event. Event: B pukul 16.00.');
    });

    test('tasks only', () {
      expect(answer(agenda(include: {AgendaPart.tasks}, tasks: ['A', 'B'])),
          'Hari ini ada 2 task. Task: A, B.');
      expect(answer(agenda(include: {AgendaPart.tasks})),
          'Hari ini tidak ada task.');
    });

    test('events only', () {
      expect(
        answer(agenda(
          include: {AgendaPart.events},
          events: {'Rapat': DateTime(2026, 10, 3, 13)},
        )),
        'Hari ini ada 1 event. Event: Rapat pukul 13.00.',
      );
      expect(answer(agenda(include: {AgendaPart.events})),
          'Hari ini tidak ada event.');
    });

    test('completed tasks are mentioned', () {
      expect(answer(agenda(tasks: ['A'], completed: 2)),
          'Hari ini ada 1 task dan tidak ada event. Task: A. '
          '2 task sudah selesai.');
      expect(answer(agenda(completed: 1)),
          'Hari ini tidak ada task atau event. 1 task sudah selesai.');
    });

    test('names the day', () {
      expect(answer(agenda(day: DateTime(2026, 10, 4))),
          'Besok tidak ada task atau event.');
      expect(answer(agenda(day: DateTime(2026, 10, 5))),
          'Lusa tidak ada task atau event.');
      expect(answer(agenda(day: DateTime(2026, 10, 9))),
          'Pada 9 Oktober tidak ada task atau event.');
      expect(answer(agenda(day: DateTime(2027, 1, 4))),
          'Pada 4 Januari 2027 tidak ada task atau event.');
    });

    test('"Besok" holds across a month and year end', () {
      final composer = ResponseComposer(DateTime(2026, 12, 31, 21));
      expect(
        composer.executed(AgendaAnswered(agenda(day: DateTime(2027, 1, 1)))),
        'Besok tidak ada task atau event.',
      );
    });
  });

  group('confirmation', () {
    test('a passed time', () {
      expect(
        composer.confirmation(NeedsConfirmation(
          const [ConfirmationReason.pastTime],
          ResolvedEvent(title: 'x', start: DateTime(2026, 10, 3, 8)),
        )),
        'Waktunya sudah lewat (3 Oktober pukul 08.00). Tetap disimpan?',
      );
    });

    test('a passed day', () {
      expect(
        composer.confirmation(NeedsConfirmation(
          const [ConfirmationReason.pastDay],
          ResolvedTask(title: 'x', dueDate: DateTime(2025, 1, 1)),
        )),
        'Tanggal 1 Januari 2025 sudah lewat. Tetap disimpan?',
      );
    });

    test('an unknown project asks to save without one', () {
      expect(
        composer.confirmation(NeedsConfirmation(
          const [ConfirmationReason.unknownProject],
          ResolvedTask(
            title: 'Siram tanaman',
            dueDate: DateTime(2026, 10, 4),
            unmatchedProject: 'Garden',
          ),
        )),
        'Proyek Garden tidak ditemukan. Simpan task Siram tanaman tanpa proyek?',
      );
    });

    test('several reasons make one question', () {
      expect(
        composer.confirmation(NeedsConfirmation(
          const [
            ConfirmationReason.unknownProject,
            ConfirmationReason.pastTime,
          ],
          ResolvedTask(
            title: 'Siram tanaman',
            dueDate: DateTime(2026, 10, 3),
            reminder: DateTime(2026, 10, 3, 8),
            unmatchedProject: 'Garden',
          ),
        )),
        'Proyek Garden tidak ditemukan. Waktunya sudah lewat '
        '(3 Oktober pukul 08.00). Simpan task Siram tanaman tanpa proyek?',
      );
    });
  });

  group('clarification', () {
    test('the model\'s own question', () {
      expect(
        composer.clarification(const NeedsClarification(
          ClarificationReason.askedByAssistant,
          question: ' Jam berapa? ',
        )),
        'Jam berapa?',
      );
    });

    test('an empty question falls back to a generic one', () {
      expect(
        composer.clarification(const NeedsClarification(
          ClarificationReason.askedByAssistant,
          question: '  ',
        )),
        'Bisa dijelaskan lagi?',
      );
    });

    test('an ambiguous hour offers both readings', () {
      expect(
        composer.clarification(const NeedsClarification(
          ClarificationReason.ambiguousTime,
          timeOptions: [ClockTime(2, 0), ClockTime(14, 0)],
        )),
        'Maksudnya pukul 02.00 atau 14.00?',
      );
      expect(
        composer.clarification(const NeedsClarification(
          ClarificationReason.ambiguousTime,
          timeOptions: [ClockTime(5, 30), ClockTime(17, 30)],
        )),
        'Maksudnya pukul 05.30 atau 17.30?',
      );
    });

    test('missing event details and unclear times', () {
      expect(
        composer.clarification(
            const NeedsClarification(ClarificationReason.missingEventDate)),
        'Event-nya hari apa?',
      );
      expect(
        composer.clarification(
            const NeedsClarification(ClarificationReason.missingEventTime)),
        'Jam berapa?',
      );
      expect(
        composer.clarification(
            const NeedsClarification(ClarificationReason.unclearTime)),
        'Jam berapa tepatnya?',
      );
    });
  });

  group('rejection', () {
    test('each reason has its own short explanation', () {
      final expected = {
        RejectionReason.emptyTitle: 'Judulnya kosong, jadi belum bisa disimpan.',
        RejectionReason.emptyText: 'Tidak ada yang bisa dicatat.',
        RejectionReason.invalidDate: 'Tanggalnya tidak valid.',
        RejectionReason.invalidTime: 'Jamnya tidak valid.',
        RejectionReason.destructive:
            'Maaf, aku belum bisa mengubah, menyelesaikan, atau menghapus data.',
        RejectionReason.notSupportedYet:
            'Maaf, aku belum bisa membantu dengan itu.',
        RejectionReason.outOfScope:
            'Maaf, permintaan itu belum bisa aku bantu.',
        RejectionReason.notUnderstood:
            'Maaf, aku belum mengerti permintaan itu.',
      };
      expect(expected.keys.toSet(), RejectionReason.values.toSet());
      for (final MapEntry(key: reason, value: text) in expected.entries) {
        expect(composer.rejection(Rejected(reason)), text);
      }
    });

    test('debug detail never reaches the user', () {
      expect(
        composer.rejection(const Rejected(
          RejectionReason.notUnderstood,
          detail: 'unexpected field "id"',
        )),
        isNot(contains('unexpected')),
      );
    });
  });
}
