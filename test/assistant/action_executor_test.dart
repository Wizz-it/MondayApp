import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/action_executor.dart';
import 'package:mondayapp/assistant/action_validator.dart';
import 'package:mondayapp/assistant/assistant_action.dart';
import 'package:mondayapp/services/app_storage.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/services/notification_service.dart';
import 'package:mondayapp/services/reminder_scheduler.dart';

/// Saturday 3 October 2026, 10:00 local.
final now = DateTime(2026, 10, 3, 10);

class RecordingNotificationService implements NotificationService {
  final Map<int, ScheduledNotification> pending = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(ScheduledNotification notification) async =>
      pending[notification.id] = notification;

  @override
  Future<void> cancel(int id) async => pending.remove(id);

  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();
}

void main() {
  late AppStore store;
  late ActionExecutor executor;

  setUp(() {
    store = AppStore(seedDate: now);
    executor = ActionExecutor(store);
  });

  test('creates a task through the store', () {
    final before = store.tasks.length;

    final result = executor.execute(ResolvedTask(
      title: 'Belajar Flutter',
      dueDate: DateTime(2026, 10, 4),
      projectId: 'project_monday',
      projectName: 'MONDAY',
    )) as TaskCreated;

    expect(store.tasks, hasLength(before + 1));
    final task = store.taskById(result.taskId)!;
    expect(task.title, 'Belajar Flutter');
    expect(task.dueDate, DateTime(2026, 10, 4));
    expect(task.reminder, isNull);
    expect(task.projectId, 'project_monday');
    expect(task.isDone, isFalse);
    expect(result.projectName, 'MONDAY');
  });

  test('creates a task with a reminder on its due day', () {
    final result = executor.execute(ResolvedTask(
      title: 'Belajar Flutter',
      dueDate: DateTime(2026, 10, 4),
      reminder: DateTime(2026, 10, 4, 7),
    )) as TaskCreated;

    final task = store.taskById(result.taskId)!;
    expect(task.dueDate, DateTime(2026, 10, 4));
    expect(task.reminder, DateTime(2026, 10, 4, 7));
    expect(result.reminder, DateTime(2026, 10, 4, 7));
  });

  test('an unmatched project is passed through, nothing is created', () {
    final projects = store.projects.length;

    final result = executor.execute(
      const ResolvedTask(title: 'x', unmatchedProject: 'Garden'),
    ) as TaskCreated;

    expect(store.projects, hasLength(projects));
    expect(store.taskById(result.taskId)!.projectId, isNull);
    expect(result.unmatchedProject, 'Garden');
  });

  test('creates an event', () {
    final result = executor.execute(ResolvedEvent(
      title: 'meeting dengan dosen',
      start: DateTime(2026, 10, 9, 14),
      description: 'Ruang 3',
    )) as EventCreated;

    final event = store.eventById(result.eventId)!;
    expect(event.title, 'meeting dengan dosen');
    expect(event.start, DateTime(2026, 10, 9, 14));
    expect(event.description, 'Ruang 3');
    expect(store.eventsOn(DateTime(2026, 10, 9)), [event]);
  });

  test('creates a note', () {
    final result = executor.execute(
      const ResolvedNote(title: 'Firebase', body: 'nanti belajar Firebase'),
    ) as NoteCreated;

    final note = store.noteById(result.noteId)!;
    expect(note.title, 'Firebase');
    expect(note.body, 'nanti belajar Firebase');
  });

  test('captures to the inbox', () {
    final result = executor.execute(
      const ResolvedInboxCapture('cari internship Unity'),
    ) as InboxCaptured;

    expect(store.inbox.single.id, result.itemId);
    expect(store.inboxNewestFirst.first.text, 'cari internship Unity');
  });

  test('an agenda query reads without changing anything', () {
    var notified = 0;
    store.addListener(() => notified++);
    final before = jsonEncode(store.toJson());

    final result = executor.execute(ResolvedAgendaQuery(
      day: DateTime(2026, 10, 3),
      include: const {AgendaPart.tasks, AgendaPart.events},
    )) as AgendaAnswered;

    expect(notified, 0);
    expect(jsonEncode(store.toJson()), before);
    expect(result.agenda.openTasks, hasLength(2));
    expect(result.agenda.events, hasLength(1));
  });

  test('every write is saved through the existing persistence', () async {
    final storage = MemoryAppStorage();
    final saved = await AppStore.open(storage, seedDate: now);
    final writer = ActionExecutor(saved);

    final task = writer.execute(ResolvedTask(
      title: 'Persisted',
      dueDate: DateTime(2026, 10, 4),
      reminder: DateTime(2026, 10, 4, 7),
    )) as TaskCreated;
    await saved.flush();

    final reopened = await AppStore.open(storage);
    final restored = reopened.taskById(task.taskId)!;
    expect(restored.reminder, DateTime(2026, 10, 4, 7));
  });

  test('a reminder set by the assistant is scheduled by the existing '
      'scheduler', () async {
    final platform = RecordingNotificationService();
    final scheduler = ReminderScheduler(store, platform, clock: () => now);
    await scheduler.start();

    final result = executor.execute(ResolvedTask(
      title: 'Belajar Flutter',
      dueDate: DateTime(2026, 10, 4),
      reminder: DateTime(2026, 10, 4, 7),
    )) as TaskCreated;
    await scheduler.idle;

    final scheduled = platform.pending[notificationIdFor(result.taskId)]!;
    expect(scheduled.when, DateTime(2026, 10, 4, 7));
    expect(scheduled.body, 'Belajar Flutter');
    scheduler.dispose();
  });
}
