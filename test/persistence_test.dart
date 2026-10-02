import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:mondayapp/main.dart';
import 'package:mondayapp/models/calendar_event.dart';
import 'package:mondayapp/models/inbox_item.dart';
import 'package:mondayapp/models/note.dart';
import 'package:mondayapp/models/project.dart';
import 'package:mondayapp/models/task.dart';
import 'package:mondayapp/models/tile_tint.dart';
import 'package:mondayapp/services/app_storage.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/widgets/task_row.dart';

/// Encodes to a JSON string and back, the way a real save/load does, so the
/// test catches anything that only survives as a live Dart object.
Map<String, dynamic> roundTrip(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

/// Saves everything [store] has queued, then opens a fresh store on the same
/// storage — the in-process equivalent of closing and relaunching the app.
Future<AppStore> restart(AppStore store, AppStorage storage) async {
  await store.flush();
  store.dispose();
  return AppStore.open(storage);
}

void main() {
  final seed = DateTime(2026, 10, 1, 9);

  group('model serialization', () {
    test('task keeps every field through JSON', () {
      final task = Task(
        id: 'task_9',
        title: 'Ship persistence',
        description: 'Line one\nLine "two"',
        projectId: 'project_monday',
        dueDate: DateTime(2026, 10, 5),
        reminder: DateTime(2026, 10, 5, 8, 30, 15, 250),
        priority: TaskPriority.high,
        isDone: true,
      );

      final copy = Task.fromJson(roundTrip(task.toJson()));

      expect(copy.id, task.id);
      expect(copy.title, task.title);
      expect(copy.description, task.description);
      expect(copy.projectId, task.projectId);
      expect(copy.dueDate, task.dueDate);
      expect(copy.reminder, task.reminder);
      expect(copy.priority, TaskPriority.high);
      expect(copy.isDone, isTrue);
    });

    test('task keeps nulls as nulls', () {
      final task = Task(id: 'task_1', title: 'Bare');

      final copy = Task.fromJson(roundTrip(task.toJson()));

      expect(copy.projectId, isNull);
      expect(copy.dueDate, isNull);
      expect(copy.reminder, isNull);
      expect(copy.description, '');
      expect(copy.priority, TaskPriority.normal);
      expect(copy.isDone, isFalse);
    });

    test('dates keep their wall-clock time and UTC flag', () {
      final local = DateTime(2026, 10, 5, 23, 59);
      final utc = DateTime.utc(2026, 10, 5, 23, 59);
      final task = Task(id: 't', title: 't', dueDate: local, reminder: utc);

      final copy = Task.fromJson(roundTrip(task.toJson()));

      expect(copy.dueDate!.isUtc, isFalse);
      expect(copy.dueDate!.day, 5);
      expect(copy.dueDate!.hour, 23);
      expect(copy.reminder!.isUtc, isTrue);
      expect(copy.reminder, utc);
    });

    test('task tolerates missing optional fields and unknown priority', () {
      final copy = Task.fromJson({
        'id': 'task_3',
        'title': 'From an older build',
        'priority': 'urgent',
      });

      expect(copy.priority, TaskPriority.normal);
      expect(copy.description, '');
      expect(copy.isDone, isFalse);
      expect(copy.dueDate, isNull);
    });

    test('project keeps name, description and tint', () {
      final project = Project(
        id: 'project_7',
        name: 'Garden',
        description: 'Spring planting',
        tint: TileTint.lilac,
      );

      final copy = Project.fromJson(roundTrip(project.toJson()));

      expect(copy.id, 'project_7');
      expect(copy.name, 'Garden');
      expect(copy.description, 'Spring planting');
      expect(copy.tint, TileTint.lilac);
    });

    test('note keeps title and body', () {
      final note = Note(id: 'note_2', title: 'Ideas', body: 'ünïcödé ✓\n\nmore');

      final copy = Note.fromJson(roundTrip(note.toJson()));

      expect(copy.id, 'note_2');
      expect(copy.title, 'Ideas');
      expect(copy.body, 'ünïcödé ✓\n\nmore');
    });

    test('inbox item keeps text and capture time', () {
      final item = InboxItem(
        id: 'inbox_4',
        text: 'Call the bank',
        capturedAt: DateTime(2026, 10, 1, 7, 15, 3),
      );

      final copy = InboxItem.fromJson(roundTrip(item.toJson()));

      expect(copy.id, 'inbox_4');
      expect(copy.text, 'Call the bank');
      expect(copy.capturedAt, item.capturedAt);
    });

    test('event keeps title, start and description', () {
      final event = CalendarEvent(
        id: 'event_5',
        title: 'Check-in',
        start: DateTime(2026, 10, 1, 14, 30),
        description: 'Room 2',
      );

      final copy = CalendarEvent.fromJson(roundTrip(event.toJson()));

      expect(copy.id, 'event_5');
      expect(copy.title, 'Check-in');
      expect(copy.start, event.start);
      expect(copy.description, 'Room 2');
    });
  });

  group('first launch', () {
    test('seeds the default data and saves it', () async {
      final storage = MemoryAppStorage();

      final store = await AppStore.open(storage, seedDate: seed);

      expect(store.tasks, hasLength(3));
      expect(store.projects, hasLength(2));
      expect(store.notes, hasLength(2));
      expect(store.events, hasLength(1));
      expect(storage.snapshot, isNotNull);
      expect(storage.writes, 1);
    });

    test('a second launch loads instead of reseeding', () async {
      final storage = MemoryAppStorage();
      final first = await AppStore.open(storage, seedDate: seed);
      final ids = first.tasks.map((t) => t.id).toList();

      var store = first;
      for (var i = 0; i < 3; i++) {
        store = await restart(store, storage);
      }

      expect(store.tasks.map((t) => t.id), ids);
      expect(store.projects, hasLength(2));
      expect(store.notes, hasLength(2));
      expect(store.events, hasLength(1));
      // Reopening alone does not write anything.
      expect(storage.writes, 1);
    });

    test('an unreadable snapshot falls back to seed data', () async {
      final storage = MemoryAppStorage('{not json');

      final store = await AppStore.open(storage, seedDate: seed);

      expect(store.tasks, hasLength(3));
      expect(() => jsonDecode(storage.snapshot!), returnsNormally);
    });
  });

  group('loading saved data', () {
    test('restores every collection and preference from a snapshot', () async {
      final storage = MemoryAppStorage(jsonEncode({
        'version': 1,
        'nextId': 12,
        'preferences': {'themeMode': 'dark', 'notificationsEnabled': false},
        'projects': [
          {'id': 'project_a', 'name': 'A', 'description': '', 'tint': 'lilac'},
        ],
        'tasks': [
          {
            'id': 'task_10',
            'title': 'Saved task',
            'description': 'desc',
            'projectId': 'project_a',
            'dueDate': '2026-10-03T00:00:00.000',
            'reminder': '2026-10-03T09:00:00.000',
            'priority': 'low',
            'isDone': true,
          },
        ],
        'events': [
          {
            'id': 'event_11',
            'title': 'Saved event',
            'start': '2026-10-04T10:00:00.000',
            'description': '',
          },
        ],
        'notes': [
          {'id': 'note_8', 'title': 'Saved note', 'body': 'Body'},
        ],
        'inbox': [
          {
            'id': 'inbox_9',
            'text': 'Saved thought',
            'capturedAt': '2026-10-01T08:00:00.000',
          },
        ],
      }));

      final store = await AppStore.open(storage, seedDate: seed);

      expect(store.themeMode, ThemeMode.dark);
      expect(store.notificationsEnabled, isFalse);
      expect(store.projects.single.tint, TileTint.lilac);

      final task = store.tasks.single;
      expect(task.title, 'Saved task');
      expect(task.isDone, isTrue);
      expect(task.priority, TaskPriority.low);
      expect(task.dueDate, DateTime(2026, 10, 3));
      expect(task.reminder, DateTime(2026, 10, 3, 9));
      expect(store.projectNameFor(task), 'A');

      expect(store.events.single.start, DateTime(2026, 10, 4, 10));
      expect(store.notes.single.body, 'Body');
      expect(store.inbox.single.text, 'Saved thought');
    });

    test('new ids never collide with restored ones', () async {
      // A snapshot whose counter is behind its data must still be safe.
      final storage = MemoryAppStorage(jsonEncode({
        'version': 1,
        'nextId': 0,
        'tasks': [
          {'id': 'task_41', 'title': 'Old'},
        ],
      }));
      final store = await AppStore.open(storage);

      final task = store.addTask(title: 'New');

      expect(task.id, isNot('task_41'));
      expect(store.tasks.map((t) => t.id).toSet(), hasLength(2));
    });
  });

  group('changes survive a restart', () {
    late MemoryAppStorage storage;
    late AppStore store;

    setUp(() async {
      storage = MemoryAppStorage();
      store = await AppStore.open(storage, seedDate: seed);
    });

    test('created task', () async {
      final task = store.addTask(
        title: 'Persist me',
        dueDate: DateTime(2026, 10, 9),
        projectId: 'project_portfolio',
        description: 'Details',
      );

      final reopened = await restart(store, storage);
      final restored = reopened.taskById(task.id)!;

      expect(restored.title, 'Persist me');
      expect(restored.dueDate, DateTime(2026, 10, 9));
      expect(restored.projectId, 'project_portfolio');
      expect(restored.description, 'Details');
      expect(reopened.tasks, hasLength(4));
    });

    test('edited task, including reminder and priority', () async {
      final task = store.tasks.first;
      store.updateTask(
        task,
        title: 'Edited',
        description: 'New notes',
        dueDate: DateTime(2026, 11, 1),
        reminder: DateTime(2026, 11, 1, 7, 45),
        priority: TaskPriority.high,
        projectId: 'project_portfolio',
      );

      final restored = (await restart(store, storage)).taskById(task.id)!;

      expect(restored.title, 'Edited');
      expect(restored.description, 'New notes');
      expect(restored.dueDate, DateTime(2026, 11, 1));
      expect(restored.reminder, DateTime(2026, 11, 1, 7, 45));
      expect(restored.priority, TaskPriority.high);
      expect(restored.projectId, 'project_portfolio');
    });

    test('cleared due date, reminder and project', () async {
      final task = store.tasks.first;
      store.updateTask(task, reminder: seed);
      store.updateTask(
        task,
        clearDueDate: true,
        clearReminder: true,
        clearProject: true,
      );

      final restored = (await restart(store, storage)).taskById(task.id)!;

      expect(restored.dueDate, isNull);
      expect(restored.reminder, isNull);
      expect(restored.projectId, isNull);
    });

    test('completion and un-completion', () async {
      final task = store.tasks.first;
      store.toggleTask(task);

      var reopened = await restart(store, storage);
      expect(reopened.taskById(task.id)!.isDone, isTrue);
      expect(reopened.tasksFor(TaskFilter.done, now: seed), hasLength(1));

      reopened.toggleTask(reopened.taskById(task.id)!);
      reopened = await restart(reopened, storage);
      expect(reopened.taskById(task.id)!.isDone, isFalse);
      expect(reopened.tasksFor(TaskFilter.done, now: seed), isEmpty);
    });

    test('deleted task', () async {
      final task = store.tasks.first;
      store.deleteTask(task);

      final reopened = await restart(store, storage);

      expect(reopened.taskById(task.id), isNull);
      expect(reopened.tasks, hasLength(2));
    });

    test('deleting a project detaches its tasks after restart too', () async {
      final project = store.projects.first;
      final attached = store.tasksForProject(project.id).map((t) => t.id);
      store.deleteProject(project);

      final reopened = await restart(store, storage);

      expect(reopened.projectById(project.id), isNull);
      for (final id in attached) {
        expect(reopened.taskById(id)!.projectId, isNull);
      }
    });

    test('projects, notes, events and inbox', () async {
      store.addProject(name: 'Garden', description: 'Planting');
      store.updateNote(store.notes.first, title: 'Renamed', body: 'Rewritten');
      store.deleteNote(store.notes.last);
      store.addEvent(title: 'Dentist', start: DateTime(2026, 10, 8, 15));
      store.deleteEvent(store.events.first);
      store.captureThought('Remember the milk');
      store.captureThought('Throwaway');
      store.deleteInboxItem(store.inbox.last);

      final reopened = await restart(store, storage);

      expect(reopened.projects.map((p) => p.name), contains('Garden'));
      expect(reopened.notes.single.title, 'Renamed');
      expect(reopened.notes.single.body, 'Rewritten');
      expect(reopened.events.single.title, 'Dentist');
      expect(reopened.events.single.start, DateTime(2026, 10, 8, 15));
      expect(reopened.inbox.single.text, 'Remember the milk');
    });

    test('theme and notification preferences', () async {
      store.toggleThemeMode();
      store.setNotificationsEnabled(false);

      final reopened = await restart(store, storage);

      expect(reopened.themeMode, ThemeMode.dark);
      expect(reopened.notificationsEnabled, isFalse);
    });

    test('ids keep counting after a restart', () async {
      final before = store.addTask(title: 'Before');

      final reopened = await restart(store, storage);
      final after = reopened.addTask(title: 'After');

      expect(after.id, isNot(before.id));
      expect(reopened.tasks.map((t) => t.id).toSet(),
          hasLength(reopened.tasks.length));
    });

    test('several changes in one go are written once', () async {
      final writesBefore = storage.writes;

      store.addTask(title: 'One');
      store.addTask(title: 'Two');
      store.toggleTask(store.tasks.first);
      await store.flush();

      expect(storage.writes, writesBefore + 1);
    });

    test('reading data does not write', () async {
      final writesBefore = storage.writes;

      store.tasksFor(TaskFilter.today, now: seed);
      store.activeDaysIn(seed);
      store.projectNameFor(store.tasks.first);
      await store.flush();

      expect(storage.writes, writesBefore);
    });
  });

  test('a store without storage never saves', () async {
    final store = AppStore(seedDate: seed);
    store.addTask(title: 'Ephemeral');
    await store.flush();
    // Nothing to assert against but the absence of errors; the in-memory
    // path used by the other test files must keep working unchanged.
    expect(store.tasks, hasLength(4));
  });

  group('shared_preferences storage', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('round-trips a store through the real adapter', () async {
      final storage = SharedPreferencesAppStorage();
      expect(await storage.read(), isNull);

      final store = await AppStore.open(storage, seedDate: seed);
      final task = store.addTask(title: 'Through prefs');

      final reopened = await restart(store, SharedPreferencesAppStorage());

      expect(reopened.taskById(task.id)!.title, 'Through prefs');
      expect(
        await SharedPreferencesAsync().getString('monday.state'),
        isNotNull,
      );
    });
  });

  testWidgets('a task created in the UI is there after a restart',
      (tester) async {
    final storage = MemoryAppStorage();
    final store = await AppStore.open(storage, seedDate: seed);

    await tester.pumpWidget(MondayApp(store: store));
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What needs to get done?'),
      'Survive the restart',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MondayCheckbox).first);
    await tester.pumpAndSettle();
    await store.flush();

    // Relaunch: tear the app down and boot a new one from storage.
    await tester.pumpWidget(const SizedBox());
    final reopened = await AppStore.open(storage);
    await tester.pumpWidget(MondayApp(store: reopened));
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Survive the restart'), findsOneWidget);
    // Three seeded + one created, minus the one checked off.
    expect(find.byType(TaskRow), findsNWidgets(3));
    expect(reopened.tasks.where((t) => t.isDone), hasLength(1));
  });
}
