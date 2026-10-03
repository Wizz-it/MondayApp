import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/models/inbox_item.dart';
import 'package:mondayapp/screens/inbox_screen.dart';
import 'package:mondayapp/services/app_storage.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/services/notification_service.dart';
import 'package:mondayapp/services/reminder_scheduler.dart';
import 'package:mondayapp/theme/app_theme.dart';
import 'package:mondayapp/widgets/monday_buttons.dart';

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

/// Records every platform call, to prove inbox changes never cause one.
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

/// Text of the inbox rows, top to bottom.
List<String> rowTexts(AppStore store) =>
    store.inboxNewestFirst.map((i) => i.text).toList();

void main() {
  final seed = DateTime(2026, 10, 1, 9);

  group('store inbox operations', () {
    late AppStore store;

    setUp(() => store = AppStore(seedDate: seed));

    test('starts empty: there is no seeded inbox content', () {
      expect(store.inbox, isEmpty);
    });

    test('captureThought adds an item stamped with the capture time', () {
      final before = DateTime.now();
      final item = store.captureThought('Call the bank');
      final after = DateTime.now();

      expect(store.inbox, [item]);
      expect(item.text, 'Call the bank');
      expect(item.capturedAt.isBefore(before), isFalse);
      expect(item.capturedAt.isAfter(after), isFalse);
      expect(item.capturedAt.isUtc, isFalse);
    });

    test('newest captures come first', () {
      store.captureThought('First');
      store.captureThought('Second');
      store.captureThought('Third');

      expect(rowTexts(store), ['Third', 'Second', 'First']);
    });

    test('order follows capture time, not list order', () {
      store.inbox.addAll([
        InboxItem(id: 'inbox_a', text: 'Middle', capturedAt: seed),
        InboxItem(
          id: 'inbox_b',
          text: 'Newest',
          capturedAt: seed.add(const Duration(hours: 2)),
        ),
        InboxItem(
          id: 'inbox_c',
          text: 'Oldest',
          capturedAt: seed.subtract(const Duration(days: 1)),
        ),
      ]);

      expect(rowTexts(store), ['Newest', 'Middle', 'Oldest']);
    });

    test('captures with the same time keep the later one first', () {
      store.inbox.addAll([
        InboxItem(id: 'inbox_a', text: 'Earlier', capturedAt: seed),
        InboxItem(id: 'inbox_b', text: 'Later', capturedAt: seed),
      ]);

      expect(rowTexts(store), ['Later', 'Earlier']);
    });

    test('deleting an item removes only that item', () {
      final a = store.captureThought('A');
      final b = store.captureThought('B');
      final c = store.captureThought('C');

      store.deleteInboxItem(b);

      expect(store.inbox, [a, c]);
    });

    test('inbox changes leave tasks, events, projects and notes alone', () {
      String snapshot() => jsonEncode({
            'tasks': [for (final t in store.tasks) t.toJson()],
            'events': [for (final e in store.events) e.toJson()],
            'projects': [for (final p in store.projects) p.toJson()],
            'notes': [for (final n in store.notes) n.toJson()],
            'notificationsEnabled': store.notificationsEnabled,
          });
      final before = snapshot();

      final item = store.captureThought('Temp');
      store.captureThought('Keep');
      store.deleteInboxItem(item);

      expect(snapshot(), before);
    });

    test('inbox changes never touch notification schedules', () async {
      final platform = RecordingNotificationService();
      final scheduler = ReminderScheduler(store, platform, clock: () => seed);
      await scheduler.start();
      platform.calls.clear();

      final item = store.captureThought('Quiet');
      store.deleteInboxItem(item);
      await scheduler.idle;

      expect(platform.calls, isEmpty);
      scheduler.dispose();
    });
  });

  group('inbox persistence', () {
    late MemoryAppStorage storage;
    late AppStore store;

    setUp(() async {
      storage = MemoryAppStorage();
      store = await AppStore.open(storage, seedDate: seed);
    });

    test('items, text and capture time survive a restart', () async {
      final item = store.captureThought('Remember the milk');

      final restored = (await restart(store, storage)).inbox.single;

      expect(restored.id, item.id);
      expect(restored.text, 'Remember the milk');
      expect(restored.capturedAt, item.capturedAt);
    });

    test('newest-first order survives a restart', () async {
      store.inbox.addAll([
        InboxItem(id: 'inbox_x', text: 'Old', capturedAt: seed),
        InboxItem(
          id: 'inbox_y',
          text: 'Older',
          capturedAt: seed.subtract(const Duration(days: 3)),
        ),
      ]);
      store.captureThought('New');

      final reopened = await restart(store, storage);

      expect(rowTexts(reopened), ['New', 'Old', 'Older']);
    });

    test('deleted items stay deleted and the rest remain', () async {
      final a = store.captureThought('A');
      final b = store.captureThought('B');
      store.deleteInboxItem(a);

      final reopened = await restart(store, storage);

      expect(reopened.inbox.map((i) => i.id), [b.id]);
      expect(jsonEncode(jsonDecode(storage.snapshot!)['inbox']),
          isNot(contains(a.id)));
    });

    test('launches never add or duplicate inbox items', () async {
      store.captureThought('Only one');

      var reopened = store;
      for (var i = 0; i < 3; i++) {
        reopened = await restart(reopened, storage);
      }

      expect(reopened.inbox.map((i) => i.text), ['Only one']);
    });

    test('a fresh install starts with an empty inbox', () async {
      var reopened = await restart(store, storage);
      reopened = await restart(reopened, storage);

      expect(reopened.inbox, isEmpty);
    });

    test('inbox ids never collide after a restart', () async {
      final before = store.captureThought('Before');

      final after =
          (await restart(store, storage)).captureThought('After');

      expect(after.id, isNot(before.id));
    });
  });

  group('inbox screen', () {
    testWidgets('shows the empty state when there is nothing captured',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const InboxScreen()));

      expect(find.text('A clear inbox feels good'), findsOneWidget);
      expect(find.text('00'), findsOneWidget);
    });

    testWidgets('shows items newest first with their capture time',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final today = DateTime.now();
      store.inbox.addAll([
        InboxItem(
          id: 'inbox_a',
          text: 'Morning thought',
          capturedAt: DateTime(today.year, today.month, today.day, 9, 5),
        ),
        InboxItem(
          id: 'inbox_b',
          text: 'Afternoon thought',
          capturedAt: DateTime(today.year, today.month, today.day, 15, 40),
        ),
      ]);

      await tester.pumpWidget(hostScreen(store, const InboxScreen()));

      expect(find.text('Today · 3:40 PM'), findsOneWidget);
      expect(find.text('Today · 9:05 AM'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Afternoon thought')).dy,
        lessThan(tester.getTopLeft(find.text('Morning thought')).dy),
      );
      expect(find.text('02'), findsOneWidget);
    });

    testWidgets('capturing from the sheet adds the item at the top',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      store.inbox.add(InboxItem(
        id: 'inbox_old',
        text: 'Older thought',
        capturedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ));

      await tester.pumpWidget(hostScreen(store, const InboxScreen()));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('Capture a thought'), findsOneWidget);
      // Just the text: no task fields.
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Capture anything...'),
          '  Book the dentist  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to inbox'));
      await tester.pumpAndSettle();

      expect(find.text('Capture a thought'), findsNothing);
      expect(store.inbox.last.text, 'Book the dentist');
      expect(
        tester.getTopLeft(find.text('Book the dentist')).dy,
        lessThan(tester.getTopLeft(find.text('Older thought')).dy),
      );
      expect(find.text('02'), findsOneWidget);
    });

    for (final (label, input) in [('blank', ''), ('whitespace-only', '   ')]) {
      testWidgets('$label text cannot be saved', (tester) async {
        useTallSurface(tester);
        final store = AppStore(seedDate: seed);

        await tester.pumpWidget(hostScreen(store, const InboxScreen()));
        // The empty state has its own + icon; use the floating button.
        await tester.tap(find.byType(MondayFab));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.widgetWithText(TextField, 'Capture anything...'), input);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save to inbox'));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // The sheet is still open and nothing was saved.
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(store.inbox, isEmpty);
      });
    }

    testWidgets('delete asks first; cancel keeps, confirm removes one',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final keep = store.captureThought('Keep me');
      final gone = store.captureThought('Delete me');

      await tester.pumpWidget(hostScreen(store, const InboxScreen()));
      final deleteGone = find.descendant(
        of: find.ancestor(
          of: find.text('Delete me'),
          matching: find.byType(InkWell),
        ).first,
        matching: find.byIcon(Icons.close),
      );

      await tester.tap(deleteGone);
      await tester.pumpAndSettle();
      expect(find.text('Delete this thought?'), findsOneWidget);
      expect(find.text('"Delete me" will be removed from your inbox.'),
          findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.inbox, [keep, gone]);
      expect(find.text('Delete me'), findsOneWidget);

      await tester.tap(deleteGone);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(store.inbox, [keep]);
      expect(find.text('Delete me'), findsNothing);
      expect(find.text('Keep me'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
    });

    testWidgets('deleting the last item shows the empty state',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      store.captureThought('Only one');

      await tester.pumpWidget(hostScreen(store, const InboxScreen()));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('A clear inbox feels good'), findsOneWidget);
    });
  });
}
