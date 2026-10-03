import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/action_executor.dart';
import 'package:mondayapp/assistant/action_validator.dart';
import 'package:mondayapp/assistant/agenda_query.dart';
import 'package:mondayapp/assistant/ai_service.dart';
import 'package:mondayapp/assistant/assistant_context.dart';
import 'package:mondayapp/assistant/assistant_controller.dart';
import 'package:mondayapp/assistant/date_resolver.dart';
import 'package:mondayapp/assistant/fake_ai_service.dart';
import 'package:mondayapp/services/app_store.dart';

/// Saturday 3 October 2026, 10:00 local.
final now = DateTime(2026, 10, 3, 10);

Map<String, Object?> task(
  String title, {
  Map<String, Object?>? date,
  Map<String, Object?>? time,
  String? project,
}) =>
    {
      'action': 'create_task',
      'title': title,
      'date': date,
      'time': time,
      'project': project,
    };

const tomorrow = {'kind': 'tomorrow'};
const today = {'kind': 'today'};
const friday = {'kind': 'weekday', 'weekday': 'friday', 'next_week': false};

/// Every canned answer the tests use, keyed by what the user typed.
final responses = <String, Object>{
  'besok jam 7 belajar Flutter': task(
    'Belajar Flutter',
    date: tomorrow,
    time: {'hour': 7, 'minute': 0, 'daypart': null},
  ),
  'besok baca buku': task('Baca buku', date: tomorrow),
  'rapat besok jam 2 siang': {
    'action': 'create_event',
    'title': 'Rapat',
    'date': tomorrow,
    'time': {'hour': 2, 'daypart': 'siang'},
    'description': null,
  },
  'simpan catatan: nanti belajar Firebase': {
    'action': 'create_note',
    'title': 'Firebase',
    'body': 'nanti belajar Firebase',
  },
  'catat: cari internship Unity': {
    'action': 'capture_inbox',
    'text': 'cari internship Unity',
  },
  'apa task-ku hari ini?': {
    'action': 'query_agenda',
    'date': today,
    'include': ['tasks', 'events'],
  },
  'cuaca hari ini?': {'action': 'unsupported', 'reason': 'weather'},
  'hapus task review': {'action': 'delete_task', 'title': 'review'},
  'rusak': '{"action": "create_task", "title": ',
  'tanpa judul': task('   '),
  'siram tanaman untuk proyek Garden': task(
    'Siram tanaman',
    date: tomorrow,
    project: 'Garden',
  ),
  'tadi pagi jam 8 olahraga': task(
    'Olahraga',
    date: today,
    time: {'hour': 8, 'daypart': 'pagi'},
  ),
  'buat event meeting dengan dosen Jumat jam 2': {
    'action': 'create_event',
    'title': 'Meeting dengan dosen',
    'date': friday,
    'time': {'hour': 2, 'minute': 0, 'daypart': null},
    'description': null,
  },
  // A new, independent request. The controller keeps nothing from the
  // previous one; whatever the model returns for this text is all that counts.
  'jam 2 siang': {
    'action': 'create_event',
    'title': 'Meeting dengan dosen',
    'date': friday,
    'time': {'hour': 2, 'minute': 0, 'daypart': 'siang'},
    'description': null,
  },
  'offline': const AIServiceException(AIFailure.offline),
  'lambat': const AIServiceException(AIFailure.timeout),
  'mati': const AIServiceException(AIFailure.unavailable, 'HTTP 503'),
};

/// Records what it is asked to run and writes nothing, so a test can prove
/// the controller itself never touches the store.
class RecordingExecutor implements ActionExecutor {
  final List<ResolvedAction> ran = [];

  @override
  ExecutionResult execute(ResolvedAction action) {
    ran.add(action);
    return switch (action) {
      ResolvedAgendaQuery(:final day, :final include) =>
        AgendaAnswered(AgendaSnapshot(day: day, include: include)),
      ResolvedTask(:final title) => TaskCreated(taskId: 'fake', title: title),
      ResolvedEvent(:final title, :final start) =>
        EventCreated(eventId: 'fake', title: title, start: start),
      ResolvedNote(:final title) => NoteCreated(noteId: 'fake', title: title),
      ResolvedInboxCapture(:final text) =>
        InboxCaptured(itemId: 'fake', text: text),
    };
  }
}

class ThrowingExecutor implements ActionExecutor {
  @override
  ExecutionResult execute(ResolvedAction action) =>
      throw StateError('disk full');
}

/// A provider with a bug, not a reported failure.
class BrokenAIService implements AIService {
  @override
  Future<String> interpret(String transcript, AssistantContext context) =>
      throw TypeError();
}

void main() {
  late AppStore store;
  late FakeAIService ai;
  late AssistantController assistant;

  setUp(() {
    store = AppStore(seedDate: now);
    ai = FakeAIService(responses: responses);
    assistant = AssistantController(store: store, ai: ai, clock: () => now);
  });

  tearDown(() => assistant.dispose());

  T stateAs<T extends AssistantState>() {
    expect(assistant.state, isA<T>());
    return assistant.state as T;
  }

  String snapshot() => jsonEncode(store.toJson());

  group('carries out requests', () {
    test('create task', () async {
      await assistant.submit('besok baca buku');

      final state = stateAs<AssistantSucceeded>();
      expect(state.message, 'Task Baca buku ditambahkan untuk 4 Oktober.');
      final created = store.taskById((state.result as TaskCreated).taskId)!;
      expect(created.title, 'Baca buku');
      expect(created.dueDate, DateTime(2026, 10, 4));
      expect(created.reminder, isNull);
    });

    test('create task with a reminder — "besok jam 7"', () async {
      await assistant.submit('besok jam 7 belajar Flutter');

      final state = stateAs<AssistantSucceeded>();
      expect(state.transcript, 'besok jam 7 belajar Flutter');
      expect(state.message, 'Task Belajar Flutter ditambahkan untuk 4 Oktober, '
          'dengan pengingat pukul 07.00.');
      final created = store.tasks.last;
      expect(created.title, 'Belajar Flutter');
      expect(created.dueDate, DateTime(2026, 10, 4));
      expect(created.reminder, DateTime(2026, 10, 4, 7));
    });

    test('create event', () async {
      await assistant.submit('rapat besok jam 2 siang');

      expect(stateAs<AssistantSucceeded>().message,
          'Event Rapat dijadwalkan pada 4 Oktober pukul 14.00.');
      expect(store.eventsOn(DateTime(2026, 10, 4)).single.start,
          DateTime(2026, 10, 4, 14));
    });

    test('create note', () async {
      await assistant.submit('simpan catatan: nanti belajar Firebase');

      expect(stateAs<AssistantSucceeded>().message, 'Catatan Firebase disimpan.');
      expect(store.notes.last.body, 'nanti belajar Firebase');
    });

    test('capture to inbox', () async {
      await assistant.submit('catat: cari internship Unity');

      expect(stateAs<AssistantSucceeded>().message, 'Sudah dicatat ke Inbox.');
      expect(store.inboxNewestFirst.first.text, 'cari internship Unity');
    });

    test('query agenda answers without changing anything', () async {
      final before = snapshot();

      await assistant.submit('apa task-ku hari ini?');

      expect(stateAs<AssistantSucceeded>().message,
          startsWith('Hari ini ada 2 task dan 1 event.'));
      expect(snapshot(), before);
    });
  });

  group('confirmation', () {
    test('an unknown project waits for the user, then runs as shown',
        () async {
      final before = snapshot();
      final projects = store.projects.length;

      await assistant.submit('siram tanaman untuk proyek Garden');

      final state = stateAs<AssistantNeedsConfirmation>();
      expect(state.reasons, [ConfirmationReason.unknownProject]);
      expect(state.withoutProject, isTrue);
      expect(state.message,
          'Proyek Garden tidak ditemukan. Simpan task Siram tanaman tanpa proyek?');
      expect((state.action as ResolvedTask).unmatchedProject, 'Garden');
      expect(snapshot(), before, reason: 'nothing runs before confirming');

      assistant.confirm();

      expect(stateAs<AssistantSucceeded>().message,
          'Task Siram tanaman ditambahkan tanpa proyek untuk 4 Oktober.');
      expect(store.tasks.last.title, 'Siram tanaman');
      expect(store.tasks.last.projectId, isNull);
      expect(store.projects, hasLength(projects));
    });

    test('a passed time waits for the user', () async {
      await assistant.submit('tadi pagi jam 8 olahraga');

      final state = stateAs<AssistantNeedsConfirmation>();
      expect(state.reasons, [ConfirmationReason.pastTime]);
      expect(state.withoutProject, isFalse);
      expect(state.message,
          'Waktunya sudah lewat (3 Oktober pukul 08.00). Tetap disimpan?');
    });

    test('cancel drops the action without running it', () async {
      final before = snapshot();
      await assistant.submit('siram tanaman untuk proyek Garden');

      assistant.cancel();

      expect(assistant.state, isA<AssistantIdle>());
      expect(snapshot(), before);

      assistant.confirm();
      expect(snapshot(), before, reason: 'nothing left to confirm');
    });

    test('confirm and cancel do nothing in other states', () async {
      assistant.confirm();
      assistant.cancel();
      expect(assistant.state, isA<AssistantIdle>());

      await assistant.submit('besok baca buku');
      final tasks = store.tasks.length;
      assistant.confirm();
      assistant.cancel();

      expect(assistant.state, isA<AssistantSucceeded>());
      expect(store.tasks, hasLength(tasks));
    });
  });

  group('clarification', () {
    test('"Jumat jam 2" asks which, and writes nothing', () async {
      final before = snapshot();

      await assistant.submit('buat event meeting dengan dosen Jumat jam 2');

      final state = stateAs<AssistantNeedsClarification>();
      expect(state.reason, ClarificationReason.ambiguousTime);
      expect(state.message, 'Maksudnya pukul 02.00 atau 14.00?');
      expect(state.timeOptions, const [ClockTime(2, 0), ClockTime(14, 0)]);
      expect(snapshot(), before);
    });

    test('the answer "jam 2 siang" is a new request that runs on its own',
        () async {
      await assistant.submit('buat event meeting dengan dosen Jumat jam 2');
      await assistant.submit('jam 2 siang');

      expect(stateAs<AssistantSucceeded>().message,
          'Event Meeting dengan dosen dijadwalkan pada 9 Oktober pukul 14.00.');
      expect(store.eventsOn(DateTime(2026, 10, 9)).single.start,
          DateTime(2026, 10, 9, 14));
      // Two independent calls; the first was not resent.
      expect(ai.calls.map((c) => c.transcript), [
        'buat event meeting dengan dosen Jumat jam 2',
        'jam 2 siang',
      ]);
    });

    test('the model\'s own question is shown', () async {
      ai.respond('ingatkan aku', {'action': 'clarify', 'question': 'Kapan?'});

      await assistant.submit('ingatkan aku');

      final state = stateAs<AssistantNeedsClarification>();
      expect(state.reason, ClarificationReason.askedByAssistant);
      expect(state.message, 'Kapan?');
    });
  });

  group('failures', () {
    void expectFailed(AssistantFailureKind kind, String message,
        {RejectionReason? rejection}) {
      final state = stateAs<AssistantFailed>();
      expect(state.kind, kind);
      expect(state.message, message);
      expect(state.rejection, rejection);
    }

    test('an unsupported request', () async {
      await assistant.submit('cuaca hari ini?');
      expectFailed(AssistantFailureKind.rejected,
          'Maaf, permintaan itu belum bisa aku bantu.',
          rejection: RejectionReason.outOfScope);
    });

    test('a request with no canned answer at all', () async {
      await assistant.submit('sesuatu yang lain');
      expectFailed(AssistantFailureKind.rejected,
          'Maaf, permintaan itu belum bisa aku bantu.',
          rejection: RejectionReason.outOfScope);
    });

    test('a destructive request', () async {
      final before = snapshot();
      await assistant.submit('hapus task review');
      expectFailed(AssistantFailureKind.rejected,
          'Maaf, aku belum bisa mengubah, menyelesaikan, atau menghapus data.',
          rejection: RejectionReason.destructive);
      expect(snapshot(), before);
    });

    test('a malformed model answer (parser failure)', () async {
      await assistant.submit('rusak');
      expectFailed(AssistantFailureKind.rejected,
          'Maaf, aku belum mengerti permintaan itu.',
          rejection: RejectionReason.notUnderstood);
    });

    test('a validation failure', () async {
      await assistant.submit('tanpa judul');
      expectFailed(AssistantFailureKind.rejected,
          'Judulnya kosong, jadi belum bisa disimpan.',
          rejection: RejectionReason.emptyTitle);
    });

    test('provider failures are explained', () async {
      await assistant.submit('offline');
      expectFailed(
          AssistantFailureKind.aiUnavailable, 'Tidak ada koneksi internet.');

      await assistant.submit('lambat');
      expectFailed(AssistantFailureKind.aiUnavailable,
          'Asisten terlalu lama merespons.');

      await assistant.submit('mati');
      expectFailed(AssistantFailureKind.aiUnavailable,
          'Asisten sedang tidak tersedia.');
    });

    test('a provider bug is treated as an outage', () async {
      final broken = AssistantController(
          store: store, ai: BrokenAIService(), clock: () => now);

      await broken.submit('apa saja');

      expect(broken.state, isA<AssistantFailed>().having(
          (s) => s.kind, 'kind', AssistantFailureKind.aiUnavailable));
      broken.dispose();
    });

    test('an executor failure is reported and nothing is half-done', () async {
      final failing = AssistantController(
        store: store,
        ai: ai,
        clock: () => now,
        executor: ThrowingExecutor(),
      );
      final before = snapshot();

      await failing.submit('besok baca buku');

      expect(failing.state, isA<AssistantFailed>()
          .having((s) => s.kind, 'kind', AssistantFailureKind.executionFailed)
          .having((s) => s.message, 'message',
              'Maaf, ada masalah saat menyimpan. Coba lagi.'));
      expect(snapshot(), before);
      failing.dispose();
    });

    test('after any failure the words can be kept in the Inbox', () async {
      await assistant.submit('offline');

      assistant.saveToInbox();

      expect(stateAs<AssistantSucceeded>().message, 'Sudah dicatat ke Inbox.');
      expect(store.inboxNewestFirst.first.text, 'offline');
    });

    test('saving to the Inbox does nothing outside a failure', () async {
      assistant.saveToInbox();
      expect(store.inbox, isEmpty);

      await assistant.submit('besok baca buku');
      assistant.saveToInbox();
      expect(store.inbox, isEmpty);
    });
  });

  group('request handling', () {
    test('the clock is read exactly once per request', () async {
      var reads = 0;
      // Each read would be a day later: reading twice would move "besok".
      final counting = AssistantController(
        store: store,
        ai: ai,
        clock: () => now.add(Duration(days: reads++)),
      );

      await counting.submit('besok jam 7 belajar Flutter');

      expect(reads, 1);
      expect(store.tasks.last.reminder, DateTime(2026, 10, 4, 7));
      counting.dispose();
    });

    test('the AI gets that same reading as its context', () async {
      await assistant.submit('besok baca buku');

      final context = ai.calls.single.context;
      expect(context, AssistantContext(now));
      expect(context.date, '2026-10-03');
      expect(context.time, '10:00');
      expect(context.weekday, 'saturday');
    });

    test('the AI gets the transcript trimmed, and nothing else', () async {
      await assistant.submit('   besok baca buku  ');

      expect(ai.calls.single.transcript, 'besok baca buku');
    });

    test('blank text is ignored', () async {
      await assistant.submit('   ');

      expect(ai.calls, isEmpty);
      expect(assistant.state, isA<AssistantIdle>());
    });

    test('shows processing, and ignores new text until done', () async {
      ai.gate = Completer<void>();
      final states = <AssistantState>[];
      assistant.addListener(() => states.add(assistant.state));

      final first = assistant.submit('besok baca buku');
      expect(assistant.isBusy, isTrue);
      expect(stateAs<AssistantProcessing>().transcript, 'besok baca buku');

      await assistant.submit('catat: cari internship Unity');
      expect(ai.calls, hasLength(1), reason: 'second request ignored');

      ai.gate!.complete();
      await first;

      expect(assistant.isBusy, isFalse);
      expect(states.map((s) => s.runtimeType),
          [AssistantProcessing, AssistantSucceeded]);
      expect(store.inbox, isEmpty);
    });

    test('reset clears the reply but not while busy', () async {
      await assistant.submit('besok baca buku');
      assistant.reset();
      expect(assistant.state, isA<AssistantIdle>());

      ai.gate = Completer<void>();
      final pending = assistant.submit('besok baca buku');
      assistant.reset();
      expect(assistant.state, isA<AssistantProcessing>());
      ai.gate!.complete();
      await pending;
    });

    test('disposing mid-request is safe and writes nothing', () async {
      ai.gate = Completer<void>();
      final before = snapshot();
      final controller =
          AssistantController(store: store, ai: ai, clock: () => now);

      final pending = controller.submit('besok baca buku');
      controller.dispose();
      ai.gate!.complete();
      await pending;

      expect(snapshot(), before);
    });

    test('a different provider can be swapped in', () async {
      final echo = AssistantController(
        store: store,
        ai: _EchoProvider(),
        clock: () => now,
      );

      await echo.submit('beli susu');

      expect(store.inboxNewestFirst.first.text, 'beli susu');
      echo.dispose();
    });
  });

  test('the controller never writes to the store itself', () async {
    final executor = RecordingExecutor();
    final controller = AssistantController(
      store: store,
      ai: ai,
      clock: () => now,
      executor: executor,
    );
    var notified = 0;
    store.addListener(() => notified++);
    final before = snapshot();

    for (final text in responses.keys) {
      await controller.submit(text);
      controller.confirm();
      controller.saveToInbox();
    }

    // Every write the controller wanted went to the executor...
    expect(executor.ran, isNotEmpty);
    expect(executor.ran.whereType<ResolvedTask>().map((t) => t.title),
        containsAll(['Belajar Flutter', 'Siram tanaman', 'Olahraga']));
    expect(executor.ran.whereType<ResolvedInboxCapture>(), isNotEmpty);
    // ...and with an executor that writes nothing, nothing was written.
    expect(notified, 0);
    expect(snapshot(), before);
    controller.dispose();
  });
}

class _EchoProvider implements AIService {
  @override
  Future<String> interpret(String transcript, AssistantContext context) async =>
      jsonEncode({'action': 'capture_inbox', 'text': transcript});
}
