import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/action_executor.dart';
import 'package:mondayapp/assistant/action_parser.dart';
import 'package:mondayapp/assistant/action_validator.dart';
import 'package:mondayapp/assistant/response_composer.dart';
import 'package:mondayapp/services/app_store.dart';

/// Saturday 3 October 2026, 10:00 local.
final now = DateTime(2026, 10, 3, 10);

/// The whole local path a model's answer will take, minus the model: parse,
/// validate, execute when ready, compose the reply. The JSON below stands in
/// for what the model would return for each example request.
class Pipeline {
  Pipeline(this.store)
      : validator = ActionValidator(store, clock: () => now),
        executor = ActionExecutor(store);

  final AppStore store;
  final ActionValidator validator;
  final ActionExecutor executor;
  final composer = ResponseComposer(now);
  static const parser = ActionParser();

  ValidationResult validate(Map<String, Object?> modelOutput) =>
      validator.validate(parser.parseJson(jsonEncode(modelOutput)));

  /// Runs a request that should need no confirmation, returning the reply.
  String run(Map<String, Object?> modelOutput) {
    final result = validate(modelOutput);
    return switch (result) {
      Ready(:final action) => composer.executed(executor.execute(action)),
      NeedsConfirmation() => composer.confirmation(result),
      NeedsClarification() => composer.clarification(result),
      Rejected() => composer.rejection(result),
    };
  }
}

void main() {
  late AppStore store;
  late Pipeline pipeline;

  setUp(() {
    store = AppStore(seedDate: now);
    pipeline = Pipeline(store);
  });

  test('"MONDAY, apa task-ku hari ini?"', () {
    final before = jsonEncode(store.toJson());

    final reply = pipeline.run({
      'action': 'query_agenda',
      'date': {'kind': 'today'},
      'include': ['tasks'],
    });

    expect(reply, 'Hari ini ada 2 task. '
        'Task: Review MONDAY wireframes, Send portfolio update.');
    expect(jsonEncode(store.toJson()), before);
  });

  test('"Tambahkan task belajar Flutter besok jam 7"', () {
    final reply = pipeline.run({
      'action': 'create_task',
      'title': 'Belajar Flutter',
      'date': {'kind': 'tomorrow'},
      'time': {'hour': 7, 'minute': null, 'daypart': null},
      'project': null,
    });

    expect(reply, 'Task Belajar Flutter ditambahkan untuk 4 Oktober, '
        'dengan pengingat pukul 07.00.');
    final task = store.tasks.last;
    expect(task.title, 'Belajar Flutter');
    expect(task.dueDate, DateTime(2026, 10, 4));
    expect(task.reminder, DateTime(2026, 10, 4, 7));
  });

  test('"Buat event meeting dengan dosen hari Jumat jam 2" — asks which 2', () {
    final before = store.events.length;

    expect(
      pipeline.run({
        'action': 'create_event',
        'title': 'Meeting dengan dosen',
        'date': {'kind': 'weekday', 'weekday': 'friday', 'next_week': false},
        'time': {'hour': 2, 'minute': 0, 'daypart': null},
        'description': null,
      }),
      'Maksudnya pukul 02.00 atau 14.00?',
    );
    expect(store.events, hasLength(before), reason: 'nothing written yet');

    // The answer ("jam 2 siang") comes back as a new request.
    expect(
      pipeline.run({
        'action': 'create_event',
        'title': 'Meeting dengan dosen',
        'date': {'kind': 'weekday', 'weekday': 'friday'},
        'time': {'hour': 2, 'daypart': 'siang'},
      }),
      'Event Meeting dengan dosen dijadwalkan pada 9 Oktober pukul 14.00.',
    );
    expect(store.eventsOn(DateTime(2026, 10, 9)).single.start,
        DateTime(2026, 10, 9, 14));
  });

  test('a task for a project that does not exist asks first', () {
    final projects = store.projects.length;
    final tasks = store.tasks.length;

    final result = pipeline.validate({
      'action': 'create_task',
      'title': 'Siram tanaman',
      'date': {'kind': 'tomorrow'},
      'time': null,
      'project': 'Garden',
    }) as NeedsConfirmation;

    expect(pipeline.composer.confirmation(result),
        'Proyek Garden tidak ditemukan. Simpan task Siram tanaman tanpa proyek?');
    expect(store.tasks, hasLength(tasks), reason: 'nothing written yet');

    // The user agrees.
    final created = pipeline.executor.execute(result.action) as TaskCreated;

    expect(pipeline.composer.executed(created),
        'Task Siram tanaman ditambahkan tanpa proyek untuk 4 Oktober.');
    expect(store.taskById(created.taskId)!.projectId, isNull);
    expect(store.projects, hasLength(projects));
  });

  test('"Simpan catatan: nanti belajar Firebase"', () {
    expect(
      pipeline.run({
        'action': 'create_note',
        'title': 'Firebase',
        'body': 'nanti belajar Firebase',
      }),
      'Catatan Firebase disimpan.',
    );
    expect(store.notes.last.body, 'nanti belajar Firebase');
  });

  test('"Catat: cari internship Unity"', () {
    expect(
      pipeline.run({'action': 'capture_inbox', 'text': 'cari internship Unity'}),
      'Sudah dicatat ke Inbox.',
    );
    expect(store.inboxNewestFirst.first.text, 'cari internship Unity');
  });

  test('"Apa yang harus aku lakukan besok?"', () {
    store.addEvent(title: 'Lari pagi', start: DateTime(2026, 10, 4, 6, 30));

    expect(
      pipeline.run({
        'action': 'query_agenda',
        'date': {'kind': 'tomorrow'},
        'include': ['tasks', 'events'],
      }),
      'Besok tidak ada task dan ada 1 event. Event: Lari pagi pukul 06.30.',
    );
  });

  test('a delete request is refused and changes nothing', () {
    final before = jsonEncode(store.toJson());

    expect(
      pipeline.run({'action': 'delete_task', 'id': 'task_0'}),
      'Maaf, aku belum bisa mengubah, menyelesaikan, atau menghapus data.',
    );
    expect(jsonEncode(store.toJson()), before);
  });

  test('a broken model answer is refused and changes nothing', () {
    final before = jsonEncode(store.toJson());
    final validator = pipeline.validator;

    final result = validator.validate(
        Pipeline.parser.parseJson('{"action": "create_task", "title": '));

    expect(pipeline.composer.rejection(result as Rejected),
        'Maaf, aku belum mengerti permintaan itu.');
    expect(jsonEncode(store.toJson()), before);
  });

  test('an event without a time is asked about, not guessed', () {
    final before = store.events.length;

    expect(
      pipeline.run({
        'action': 'create_event',
        'title': 'Rapat',
        'date': {'kind': 'tomorrow'},
        'time': null,
      }),
      'Jam berapa?',
    );
    expect(store.events, hasLength(before));
  });
}
