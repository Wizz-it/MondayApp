import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/screens/note_detail_screen.dart';
import 'package:mondayapp/screens/notes_screen.dart';
import 'package:mondayapp/services/app_storage.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/services/notification_service.dart';
import 'package:mondayapp/services/reminder_scheduler.dart';
import 'package:mondayapp/theme/app_theme.dart';

Widget hostScreen(AppStore store, Widget child) {
  return AppScope(
    store: store,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        theme: mondayLightTheme,
        home: child,
      ),
    ),
  );
}

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(440, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Saves, then opens a fresh store on the same storage, as a relaunch would.
Future<AppStore> restart(AppStore store, AppStorage storage) async {
  await store.flush();
  store.dispose();
  return AppStore.open(storage);
}

/// Records every platform call, to prove notes never cause one.
class RecordingNotificationService implements NotificationService {
  final List<String> calls = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return true;
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async =>
      calls.add('schedule ${notification.id}');

  @override
  Future<void> cancel(int id) async => calls.add('cancel $id');

  @override
  Future<Set<int>> pendingIds() async => {};
}

void main() {
  final seed = DateTime(2026, 10, 1, 9);

  group('store note operations', () {
    late AppStore store;

    setUp(() => store = AppStore(seedDate: seed));

    test('addNote creates a note that can be looked up by id', () {
      final note = store.addNote(title: 'Groceries', body: 'Eggs, rice');

      expect(store.noteById(note.id), same(note));
      expect(note.title, 'Groceries');
      expect(note.body, 'Eggs, rice');
      expect(store.notes, hasLength(3));
    });

    test('a note may have an empty body', () {
      final note = store.addNote(title: 'Just a title');

      expect(note.body, isEmpty);
    });

    test('updateNote changes title and body', () {
      final note = store.notes.first;

      store.updateNote(note, title: 'Roadmap', body: 'Q4 plans');

      expect(note.title, 'Roadmap');
      expect(note.body, 'Q4 plans');
    });

    test('updateNote leaves fields it was not given alone', () {
      final note = store.notes.first;

      store.updateNote(note, title: 'Renamed');
      expect(note.body, 'Ideas for future MONDAY features.');

      store.updateNote(note, body: 'New body');
      expect(note.title, 'Renamed');
    });

    test('several notes can exist side by side', () {
      final a = store.addNote(title: 'A');
      final b = store.addNote(title: 'B');

      expect(store.notes.map((n) => n.title),
          ['Project ideas', 'Meeting notes', 'A', 'B']);
      expect(a.id, isNot(b.id));
    });

    test('deleting a note removes only that note', () {
      final keep = store.notes.first;
      final gone = store.notes.last;

      store.deleteNote(gone);

      expect(store.noteById(gone.id), isNull);
      expect(store.noteById(keep.id), same(keep));
      expect(store.notes, [keep]);
    });

    test('noteById returns null for unknown ids', () {
      expect(store.noteById('note_999'), isNull);
    });

    test('note changes leave tasks, events, projects and inbox alone', () {
      store.captureThought('Call the bank');
      final before = jsonEncode({
        'tasks': [for (final t in store.tasks) t.toJson()],
        'events': [for (final e in store.events) e.toJson()],
        'projects': [for (final p in store.projects) p.toJson()],
        'inbox': [for (final i in store.inbox) i.toJson()],
        'notificationsEnabled': store.notificationsEnabled,
      });

      final note = store.addNote(title: 'Temp', body: 'x');
      store.updateNote(note, title: 'Temp 2', body: 'y');
      store.deleteNote(note);
      store.deleteNote(store.notes.first);

      final after = jsonEncode({
        'tasks': [for (final t in store.tasks) t.toJson()],
        'events': [for (final e in store.events) e.toJson()],
        'projects': [for (final p in store.projects) p.toJson()],
        'inbox': [for (final i in store.inbox) i.toJson()],
        'notificationsEnabled': store.notificationsEnabled,
      });
      expect(after, before);
    });

    test('note changes never touch notification schedules', () async {
      final platform = RecordingNotificationService();
      final scheduler =
          ReminderScheduler(store, platform, clock: () => seed);
      await scheduler.start();
      platform.calls.clear();

      final note = store.addNote(title: 'Quiet');
      store.updateNote(note, title: 'Still quiet', body: 'Typing');
      store.deleteNote(note);
      await scheduler.idle;

      expect(platform.calls, isEmpty);
      scheduler.dispose();
    });
  });

  group('note persistence', () {
    late MemoryAppStorage storage;
    late AppStore store;

    setUp(() async {
      storage = MemoryAppStorage();
      store = await AppStore.open(storage, seedDate: seed);
    });

    test('a created and edited note survives a restart', () async {
      final note = store.addNote(title: 'Draft', body: 'First pass');
      store.updateNote(note, title: 'Final', body: 'Second pass\nwith lines');

      final restored = (await restart(store, storage)).noteById(note.id)!;

      expect(restored.title, 'Final');
      expect(restored.body, 'Second pass\nwith lines');
    });

    test('an empty body survives a restart', () async {
      final note = store.addNote(title: 'Title only');

      final restored = (await restart(store, storage)).noteById(note.id)!;

      expect(restored.body, isEmpty);
    });

    test('a deleted note stays deleted and the rest remain', () async {
      final a = store.addNote(title: 'A');
      final b = store.addNote(title: 'B');
      store.deleteNote(a);

      final reopened = await restart(store, storage);

      expect(reopened.noteById(a.id), isNull);
      expect(reopened.noteById(b.id)!.title, 'B');
      expect(reopened.notes.map((n) => n.title),
          ['Project ideas', 'Meeting notes', 'B']);
    });

    test('seed notes are not duplicated across launches', () async {
      var reopened = store;
      for (var i = 0; i < 3; i++) {
        reopened = await restart(reopened, storage);
      }

      expect(reopened.notes.map((n) => n.title),
          ['Project ideas', 'Meeting notes']);
    });

    test('deleted seed notes do not come back', () async {
      store.notes.toList().forEach(store.deleteNote);

      final reopened = await restart(store, storage);

      expect(reopened.notes, isEmpty);
    });

    test('note ids never collide after a restart', () async {
      final before = store.addNote(title: 'Before');

      final after = (await restart(store, storage)).addNote(title: 'After');

      expect(after.id, isNot(before.id));
    });
  });

  group('notes screen', () {
    testWidgets('shows every note from the store', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const NotesScreen()));

      expect(find.text('Project ideas'), findsOneWidget);
      expect(find.text('Meeting notes'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no notes',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed)..notes.clear();

      await tester.pumpWidget(hostScreen(store, const NotesScreen()));

      expect(find.text('Nothing written down yet'), findsOneWidget);
    });

    testWidgets('creating a note from the sheet shows it immediately',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const NotesScreen()));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('New note'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Name your note'), '  Groceries ');
      await tester.enterText(
          find.widgetWithText(TextField, 'Add a little more detail...'),
          'Eggs and rice');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create note'));
      await tester.pumpAndSettle();

      expect(find.text('New note'), findsNothing);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Eggs and rice'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
    });

    testWidgets('a note can be created with an empty body', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const NotesScreen()));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Name your note'), 'Title only');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create note'));
      await tester.pumpAndSettle();

      expect(find.text('Title only'), findsOneWidget);
      expect(find.text('No detail yet.'), findsOneWidget);
      expect(store.notes.last.body, isEmpty);
    });

    testWidgets('a blank title cannot be saved', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const NotesScreen()));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Name your note'), '   ');
      await tester.enterText(
          find.widgetWithText(TextField, 'Add a little more detail...'),
          'Body without a title');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create note'));
      await tester.pumpAndSettle();

      expect(find.text('New note'), findsOneWidget);
      expect(store.notes, hasLength(2));
    });

    testWidgets('tapping a note opens its detail', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const NotesScreen()));
      await tester.tap(find.text('Meeting notes'));
      await tester.pumpAndSettle();

      expect(find.byType(NoteDetailScreen), findsOneWidget);
      expect(find.text('Meeting notes.', findRichText: true), findsOneWidget);
      expect(find.text('A place for the important details.'), findsOneWidget);
    });

    testWidgets('long-press asks, then deletes from the grid',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const NotesScreen()));
      await tester.longPress(find.text('Meeting notes'));
      await tester.pumpAndSettle();
      expect(find.text('Delete note?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.notes, hasLength(2));

      await tester.longPress(find.text('Meeting notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Meeting notes'), findsNothing);
      expect(find.text('Project ideas'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
    });
  });

  group('note detail', () {
    testWidgets('the edit sheet changes title and body', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final note = store.notes.first;

      await tester.pumpWidget(hostScreen(store, const NotesScreen()));
      await tester.tap(find.text('Project ideas'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Edit note'), findsOneWidget);

      final sheet = find.byType(BottomSheet);
      await tester.enterText(
          find.descendant(
              of: sheet, matching: find.widgetWithText(TextField, 'Project ideas')),
          'Roadmap');
      await tester.enterText(
          find.descendant(
              of: sheet,
              matching: find.widgetWithText(
                  TextField, 'Ideas for future MONDAY features.')),
          'Q4 plans');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Edit note'), findsNothing);
      expect(note.title, 'Roadmap');
      expect(note.body, 'Q4 plans');
      // Detail and grid both reflect the change.
      expect(find.text('Roadmap.', findRichText: true), findsOneWidget);
      expect(find.text('Q4 plans'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Roadmap'), findsOneWidget);
      expect(find.text('Project ideas'), findsNothing);
    });

    testWidgets('changing only the title keeps the body', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final note = store.notes.last;

      await tester.pumpWidget(
          hostScreen(store, NoteDetailScreen(noteId: note.id)));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Meeting notes'), 'Standup notes');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(note.title, 'Standup notes');
      expect(note.body, 'A place for the important details.');
    });

    testWidgets('the edit sheet will not save a blank title', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final note = store.notes.first;

      await tester.pumpWidget(
          hostScreen(store, NoteDetailScreen(noteId: note.id)));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Project ideas'), '  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Edit note'), findsOneWidget);
      expect(note.title, 'Project ideas');
    });

    testWidgets('typing in the body card updates the note', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final note = store.notes.first;

      await tester.pumpWidget(
          hostScreen(store, NoteDetailScreen(noteId: note.id)));
      await tester.enterText(
          find.widgetWithText(TextField, 'Ideas for future MONDAY features.'),
          'Typed inline');
      await tester.pumpAndSettle();

      expect(note.body, 'Typed inline');
      expect(note.title, 'Project ideas');
    });

    testWidgets('deleting asks first, closes, and keeps other notes',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final gone = store.notes.first;
      final keep = store.notes.last;

      await tester.pumpWidget(hostScreen(store, const NotesScreen()));
      await tester.tap(find.text(gone.title));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete note'));
      await tester.pumpAndSettle();
      expect(find.text('Delete note?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.noteById(gone.id), same(gone));
      expect(find.byType(NoteDetailScreen), findsOneWidget);

      await tester.tap(find.text('Delete note'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(NoteDetailScreen), findsNothing);
      expect(store.noteById(gone.id), isNull);
      expect(find.text(gone.title), findsNothing);
      expect(find.text(keep.title), findsOneWidget);
    });

    testWidgets('a deleted note cannot be reopened', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final note = store.notes.first;
      store.deleteNote(note);

      await tester.pumpWidget(
          hostScreen(store, NoteDetailScreen(noteId: note.id)));

      expect(store.noteById(note.id), isNull);
      expect(find.text('This note is no longer in your notes.'),
          findsOneWidget);
      expect(find.text('Delete note'), findsNothing);
    });

    testWidgets('reports a note deleted while open', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final note = store.notes.first;

      await tester.pumpWidget(
          hostScreen(store, NoteDetailScreen(noteId: note.id)));
      store.deleteNote(note);
      await tester.pumpAndSettle();

      expect(find.text('This note is no longer in your notes.'),
          findsOneWidget);
    });
  });
}
