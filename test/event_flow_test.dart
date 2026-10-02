import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/main.dart';
import 'package:mondayapp/screens/calendar_screen.dart';
import 'package:mondayapp/screens/event_detail_screen.dart';
import 'package:mondayapp/services/app_storage.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/theme/app_theme.dart';
import 'package:mondayapp/utils/date_labels.dart';
import 'package:mondayapp/widgets/month_grid.dart';

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

/// A day in the current month other than today, so the calendar never has to
/// change month to reach it.
DateTime otherDayThisMonth() {
  final today = dayOf(DateTime.now());
  return DateTime(today.year, today.month, today.day == 15 ? 16 : 15);
}

/// Taps [day] in the calendar's month grid (not in a date picker).
Future<void> tapGridDay(WidgetTester tester, int day) async {
  await tester.tap(find.descendant(
    of: find.byType(MonthGrid),
    matching: find.text('$day'),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final seed = DateTime(2026, 10, 1, 9);

  group('store event operations', () {
    late AppStore store;

    setUp(() => store = AppStore(seedDate: seed));

    test('addEvent creates an event that can be looked up', () {
      final start = DateTime(2026, 10, 7, 10, 15);
      final event = store.addEvent(
        title: 'Dentist',
        start: start,
        description: 'Bring the form',
      );

      expect(store.eventById(event.id), same(event));
      expect(event.title, 'Dentist');
      expect(event.start, start);
      expect(event.description, 'Bring the form');
    });

    test('updateEvent changes title, start and description', () {
      final event = store.addEvent(title: 'Draft', start: seed);
      final moved = DateTime(2026, 10, 12, 16, 45);

      store.updateEvent(
        event,
        title: 'Final',
        start: moved,
        description: 'Updated',
      );

      expect(event.title, 'Final');
      expect(event.start, moved);
      expect(event.description, 'Updated');
    });

    test('updateEvent leaves fields it was not given alone', () {
      final event = store.addEvent(
        title: 'Keep',
        start: seed,
        description: 'Keep too',
      );

      store.updateEvent(event, title: 'Renamed');

      expect(event.start, seed);
      expect(event.description, 'Keep too');
    });

    test('deleteEvent removes only that event', () {
      final a = store.addEvent(title: 'A', start: seed);
      final b = store.addEvent(title: 'B', start: seed);
      final before = store.events.length;

      store.deleteEvent(a);

      expect(store.eventById(a.id), isNull);
      expect(store.eventById(b.id), same(b));
      expect(store.events, hasLength(before - 1));
    });

    test('eventsOn returns the day\'s events, in time order', () {
      final day = DateTime(2026, 10, 9);
      final late = store.addEvent(
          title: 'Late', start: DateTime(2026, 10, 9, 23, 59));
      final early =
          store.addEvent(title: 'Early', start: DateTime(2026, 10, 9));
      store.addEvent(title: 'Next day', start: DateTime(2026, 10, 10));
      store.addEvent(title: 'Day before', start: DateTime(2026, 10, 8, 23, 59));

      expect(store.eventsOn(day), [early, late]);
    });

    test('the calendar marks days that have events', () {
      store.addEvent(title: 'Mark', start: DateTime(2026, 10, 20, 8));

      expect(store.activeDaysIn(DateTime(2026, 10)), contains(20));
      expect(store.activeDaysIn(DateTime(2026, 11)), isNot(contains(20)));
    });

    test('event changes notify listeners', () {
      var notified = 0;
      store.addListener(() => notified++);

      final event = store.addEvent(title: 'Ping', start: seed);
      store.updateEvent(event, title: 'Pong');
      store.deleteEvent(event);

      expect(notified, 3);
    });
  });

  group('event persistence', () {
    late MemoryAppStorage storage;
    late AppStore store;

    setUp(() async {
      storage = MemoryAppStorage();
      store = await AppStore.open(storage, seedDate: seed);
    });

    test('a created event survives a restart', () async {
      final event = store.addEvent(
        title: 'Persisted',
        start: DateTime(2026, 10, 14, 18, 5),
        description: 'With details',
      );

      final reopened = await restart(store, storage);
      final restored = reopened.eventById(event.id)!;

      expect(restored.title, 'Persisted');
      expect(restored.start, DateTime(2026, 10, 14, 18, 5));
      expect(restored.start.isUtc, isFalse);
      expect(restored.description, 'With details');
    });

    test('edits survive a restart', () async {
      final event = store.events.first;
      store.updateEvent(
        event,
        title: 'Moved check-in',
        start: DateTime(2026, 11, 3, 7, 30),
        description: 'Now in November',
      );

      final restored = (await restart(store, storage)).eventById(event.id)!;

      expect(restored.title, 'Moved check-in');
      expect(restored.start, DateTime(2026, 11, 3, 7, 30));
      expect(restored.description, 'Now in November');
    });

    test('several events survive, and deleting one keeps the rest', () async {
      final a = store.addEvent(title: 'A', start: DateTime(2026, 10, 5, 9));
      final b = store.addEvent(title: 'B', start: DateTime(2026, 10, 5, 11));
      final c = store.addEvent(title: 'C', start: DateTime(2026, 10, 6, 9));
      store.deleteEvent(b);

      final reopened = await restart(store, storage);

      expect(reopened.eventById(a.id)!.title, 'A');
      expect(reopened.eventById(b.id), isNull);
      expect(reopened.eventById(c.id)!.title, 'C');
      expect(reopened.eventsOn(DateTime(2026, 10, 5)).map((e) => e.title),
          ['A']);
    });

    test('the seed event is not duplicated across launches', () async {
      var reopened = store;
      for (var i = 0; i < 3; i++) {
        reopened = await restart(reopened, storage);
      }

      expect(
        reopened.events.where((e) => e.title == 'Project check-in'),
        hasLength(1),
      );
    });

    test('a deleted seed event stays deleted', () async {
      store.deleteEvent(store.events.single);

      final reopened = await restart(store, storage);

      expect(reopened.events, isEmpty);
    });

    test('event ids never collide after a restart', () async {
      final before = store.addEvent(title: 'Before', start: seed);

      final reopened = await restart(store, storage);
      final after = reopened.addEvent(title: 'After', start: seed);

      expect(after.id, isNot(before.id));
    });
  });

  group('calendar screen', () {
    testWidgets('shows the current month with today\'s seeded event',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore();

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));

      expect(find.text(monthYear(DateTime.now())), findsOneWidget);
      expect(find.text("Today's schedule"), findsOneWidget);
      expect(find.text('Project check-in'), findsOneWidget);
      expect(find.text('Event · 2:30 PM'), findsOneWidget);
    });

    testWidgets('selecting a date shows only that date\'s events',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore();
      final other = otherDayThisMonth();
      store.addEvent(
        title: 'Other day event',
        start: DateTime(other.year, other.month, other.day, 11),
      );

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));
      expect(find.text('Other day event'), findsNothing);

      await tapGridDay(tester, other.day);

      expect(find.text('Other day event'), findsOneWidget);
      expect(find.text('Event · 11:00 AM'), findsOneWidget);
      expect(find.text('Project check-in'), findsNothing);
    });

    testWidgets('an empty date shows the empty state', (tester) async {
      useTallSurface(tester);
      final store = AppStore();
      final other = otherDayThisMonth();
      // A seeded task (due today + 2) could land on the chosen day.
      store.tasks.clear();

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));
      await tapGridDay(tester, other.day);

      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('month navigation reaches events in the next month',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore();
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1);
      store.addEvent(
        title: 'Next month event',
        start: DateTime(nextMonth.year, nextMonth.month, 10, 9),
      );

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));
      await tester.tap(find.descendant(
        of: find.byType(MonthGrid),
        matching: find.byIcon(Icons.chevron_right),
      ));
      await tester.pumpAndSettle();

      expect(find.text(monthYear(nextMonth)), findsOneWidget);

      await tapGridDay(tester, 10);

      expect(find.text('Next month event'), findsOneWidget);
    });

    testWidgets('creating an event from the sheet shows it immediately',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore();

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('New event'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, "What's happening?"),
        'Team lunch',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Add a little more detail...'),
        'Booked for six',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();

      expect(find.text('New event'), findsNothing);
      expect(find.text('Team lunch'), findsOneWidget);
      // The sheet defaults to 9:00 on the selected day.
      expect(find.text('Event · 9:00 AM'), findsOneWidget);

      final created = store.events.singleWhere((e) => e.title == 'Team lunch');
      expect(isSameDay(created.start, DateTime.now()), isTrue);
      expect(created.description, 'Booked for six');
    });

    testWidgets('an event cannot be created without a title', (tester) async {
      useTallSurface(tester);
      final store = AppStore();
      final before = store.events.length;

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, "What's happening?"),
        '   ',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();

      expect(find.text('New event'), findsOneWidget);
      expect(store.events, hasLength(before));
    });

    testWidgets('creating on another date moves the calendar there',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore();
      final other = otherDayThisMonth();

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, "What's happening?"),
        'Elsewhere',
      );

      await tester.tap(find.text(slashDate(dayOf(DateTime.now()))));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('${other.day}'),
      ));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(slashDate(other)), findsOneWidget);

      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();

      expect(find.text('Elsewhere'), findsOneWidget);
      expect(find.text('Schedule for ${relativeDayLabel(other)}'),
          findsOneWidget);
      expect(store.events.last.start, DateTime(other.year, other.month,
          other.day, 9));
    });

    testWidgets('tapping an event opens its detail', (tester) async {
      useTallSurface(tester);
      final store = AppStore();

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));
      await tester.tap(find.text('Project check-in'));
      await tester.pumpAndSettle();

      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('YOUR EVENT'), findsOneWidget);
      expect(find.text('2:30 PM'), findsOneWidget);
    });

    testWidgets('editing from detail updates the calendar', (tester) async {
      useTallSurface(tester);
      final store = AppStore();
      final event = store.events.single;

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));
      await tester.tap(find.text('Project check-in'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Edit event'), findsOneWidget);
      // The sheet opens pre-filled with the event's date and time.
      expect(find.text(slashDate(event.start)), findsOneWidget);
      expect(find.text('14.30'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Project check-in'),
        'Project review',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Add a little more detail...'),
        'Bring the roadmap',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Edit event'), findsNothing);
      expect(event.title, 'Project review');
      expect(event.description, 'Bring the roadmap');
      // Untouched fields keep their values.
      expect(event.start.hour, 14);
      expect(event.start.minute, 30);
      expect(find.text('Bring the roadmap'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Project review'), findsOneWidget);
      expect(find.text('Project check-in'), findsNothing);
    });

    testWidgets('deleting asks first, then removes the event',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore();
      final keep = store.addEvent(
        title: 'Keep me',
        start: dayOf(DateTime.now()).add(const Duration(hours: 17)),
      );

      await tester.pumpWidget(hostScreen(store, const CalendarScreen()));
      await tester.tap(find.text('Project check-in'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();
      expect(find.text('Delete event?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.events, hasLength(2));

      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Back on the calendar, with only the other event left.
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.text('Project check-in'), findsNothing);
      expect(find.text('Keep me'), findsOneWidget);
      expect(store.events, [keep]);
    });

    testWidgets('detail reports an event that no longer exists',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore();
      final event = store.events.single;

      await tester.pumpWidget(
        hostScreen(store, EventDetailScreen(eventId: event.id)),
      );
      store.deleteEvent(event);
      await tester.pumpAndSettle();

      expect(find.text('This event is no longer on your calendar.'),
          findsOneWidget);
    });
  });

  testWidgets('an event created in the app is on the calendar after restart',
      (tester) async {
    useTallSurface(tester);
    final storage = MemoryAppStorage();
    final store = await AppStore.open(storage);

    await tester.pumpWidget(MondayApp(store: store));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, "What's happening?"),
      'Survives relaunch',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create event'));
    await tester.pumpAndSettle();
    await store.flush();

    await tester.pumpWidget(const SizedBox());
    final reopened = await AppStore.open(storage);
    await tester.pumpWidget(MondayApp(store: reopened));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    final calendar = find.byType(CalendarScreen);
    expect(find.descendant(of: calendar, matching: find.text('Survives relaunch')),
        findsOneWidget);
    expect(
        find.descendant(of: calendar, matching: find.text('Project check-in')),
        findsOneWidget);
    expect(reopened.events, hasLength(2));
  });
}
