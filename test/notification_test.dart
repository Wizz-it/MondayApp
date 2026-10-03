import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/services/app_storage.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/services/notification_service.dart';
import 'package:mondayapp/services/reminder_scheduler.dart';

/// Behaves like the platform: pending notifications are keyed by id, so
/// scheduling an id that is already pending replaces it. Survives "restarts"
/// when the same instance is handed to a new scheduler.
class FakeNotificationService implements NotificationService {
  final Map<int, ScheduledNotification> pending = {};
  final List<String> log = [];
  int permissionRequests = 0;
  bool grantPermission = true;
  bool failEverything = false;

  void _check() {
    if (failEverything) throw StateError('platform unavailable');
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    _check();
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    _check();
    log.add('schedule ${notification.id}');
    pending[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    _check();
    log.add('cancel $id');
    pending.remove(id);
  }

  @override
  Future<Set<int>> pendingIds() async {
    _check();
    return pending.keys.toSet();
  }

  /// The pending notification for a store item, if any.
  ScheduledNotification? forItem(String itemId) =>
      pending[notificationIdFor(itemId)];
}

void main() {
  // The store seeds on this day; the clock reads 9:00 that morning, so the
  // seeded 2:30 PM event is still ahead.
  final seed = DateTime(2026, 10, 1, 9);
  final later = DateTime(2026, 10, 1, 17, 45);
  final tomorrow = DateTime(2026, 10, 2, 8, 30);
  final earlier = DateTime(2026, 10, 1, 7);

  late DateTime now;
  late FakeNotificationService platform;
  late AppStore store;
  late ReminderScheduler scheduler;

  Future<void> settle() => scheduler.idle;

  setUp(() async {
    now = seed;
    platform = FakeNotificationService();
    store = AppStore(seedDate: seed);
    scheduler = ReminderScheduler(store, platform, clock: () => now);
    await scheduler.start();
    platform.log.clear();
  });

  tearDown(() => scheduler.dispose());

  group('task reminders', () {
    test('a reminder schedules a task notification', () async {
      final task = store.tasks.first;

      store.updateTask(task, reminder: later);
      await settle();

      final scheduled = platform.forItem(task.id)!;
      expect(scheduled.when, later);
      expect(scheduled.title, 'MONDAY · Task reminder');
      expect(scheduled.body, task.title);
    });

    test('editing a reminder replaces the old schedule', () async {
      final task = store.tasks.first;
      store.updateTask(task, reminder: later);
      await settle();
      platform.log.clear();

      store.updateTask(task, reminder: tomorrow);
      await settle();

      final id = notificationIdFor(task.id);
      expect(platform.log, ['cancel $id', 'schedule $id']);
      expect(platform.forItem(task.id)!.when, tomorrow);
      expect(platform.pending.values.where((n) => n.body == task.title),
          hasLength(1));
    });

    test('renaming a task updates its pending notification', () async {
      final task = store.tasks.first;
      store.updateTask(task, reminder: later);
      await settle();

      store.updateTask(task, title: 'Renamed task');
      await settle();

      expect(platform.forItem(task.id)!.body, 'Renamed task');
    });

    test('clearing a reminder cancels it', () async {
      final task = store.tasks.first;
      store.updateTask(task, reminder: later);
      await settle();

      store.updateTask(task, clearReminder: true);
      await settle();

      expect(platform.forItem(task.id), isNull);
    });

    test('completing a task cancels its reminder; reopening restores it',
        () async {
      final task = store.tasks.first;
      store.updateTask(task, reminder: later);
      await settle();

      store.toggleTask(task);
      await settle();
      expect(platform.forItem(task.id), isNull);

      store.toggleTask(task);
      await settle();
      expect(platform.forItem(task.id)!.when, later);
    });

    test('completed tasks are never scheduled', () async {
      final task = store.tasks.first..isDone = true;

      store.updateTask(task, reminder: later);
      await settle();

      expect(platform.forItem(task.id), isNull);
    });

    test('deleting a task cancels its reminder', () async {
      final task = store.tasks.first;
      store.updateTask(task, reminder: later);
      await settle();

      store.deleteTask(task);
      await settle();

      expect(platform.forItem(task.id), isNull);
    });

    test('tasks without a reminder schedule nothing', () async {
      store.addTask(title: 'No reminder', dueDate: tomorrow);
      await settle();

      expect(platform.log, isEmpty);
    });
  });

  group('event notifications', () {
    test('the seeded event was scheduled at start', () {
      final event = store.events.single;

      final scheduled = platform.forItem(event.id)!;
      expect(scheduled.when, event.start);
      expect(scheduled.title, 'MONDAY · Event');
      expect(scheduled.body, 'Project check-in · 2:30 PM');
    });

    test('a new event schedules a notification at its start', () async {
      final event = store.addEvent(title: 'Dentist', start: tomorrow);
      await settle();

      final scheduled = platform.forItem(event.id)!;
      expect(scheduled.when, tomorrow);
      expect(scheduled.body, 'Dentist · 8:30 AM');
    });

    test('editing an event replaces its notification', () async {
      final event = store.addEvent(title: 'Dentist', start: tomorrow);
      await settle();
      platform.log.clear();

      store.updateEvent(event, title: 'Orthodontist', start: later);
      await settle();

      final id = notificationIdFor(event.id);
      expect(platform.log, ['cancel $id', 'schedule $id']);
      expect(platform.forItem(event.id)!.when, later);
      expect(platform.forItem(event.id)!.body, 'Orthodontist · 5:45 PM');
    });

    test('deleting an event cancels only its notification', () async {
      final keep = store.events.single;
      final event = store.addEvent(title: 'Dentist', start: tomorrow);
      await settle();

      store.deleteEvent(event);
      await settle();

      expect(platform.forItem(event.id), isNull);
      expect(platform.forItem(keep.id), isNotNull);
    });

    test('editing only an event description schedules nothing', () async {
      store.updateEvent(store.events.single, description: 'Typing...');
      await settle();

      expect(platform.log, isEmpty);
    });
  });

  group('past times', () {
    test('a reminder in the past is not scheduled', () async {
      final task = store.tasks.first;

      store.updateTask(task, reminder: earlier);
      await settle();

      expect(platform.forItem(task.id), isNull);
      // The data itself is untouched.
      expect(task.reminder, earlier);
    });

    test('an event in the past is not scheduled', () async {
      final event = store.addEvent(title: 'Breakfast', start: earlier);
      await settle();

      expect(platform.forItem(event.id), isNull);
      expect(store.eventById(event.id)!.start, earlier);
    });

    test('moving a reminder into the past cancels the old one', () async {
      final task = store.tasks.first;
      store.updateTask(task, reminder: later);
      await settle();

      store.updateTask(task, reminder: earlier);
      await settle();

      expect(platform.forItem(task.id), isNull);
    });

    test('a reminder time passing is not treated as a change', () async {
      final task = store.tasks.first;
      store.updateTask(task, reminder: later);
      await settle();
      platform.log.clear();

      // The reminder fires; later the user edits something unrelated.
      now = later.add(const Duration(minutes: 1));
      store.updateTask(store.tasks.last, title: 'Unrelated edit');
      await settle();

      // Cancelling here would also clear the notification on screen.
      expect(platform.log, isEmpty);
    });
  });

  group('restart', () {
    test('restoring state reschedules without duplicates', () async {
      final storage = MemoryAppStorage();
      final first = await AppStore.open(storage, seedDate: seed);
      final device = FakeNotificationService();
      final run1 = ReminderScheduler(first, device, clock: () => now);
      await run1.start();
      first.updateTask(first.tasks.first, reminder: later);
      first.addEvent(title: 'Dentist', start: tomorrow);
      await run1.idle;
      await first.flush();
      final before = Map.of(device.pending);
      run1.dispose();

      for (var launch = 0; launch < 3; launch++) {
        final reopened = await AppStore.open(storage);
        final run = ReminderScheduler(reopened, device, clock: () => now);
        await run.start();
        run.dispose();
      }

      expect(device.pending, before);
      expect(device.pending, hasLength(3));
    });

    test('notifications left over for deleted items are cancelled', () async {
      final device = FakeNotificationService();
      final stale = ScheduledNotification(
        id: 999999,
        when: DateTime(2026, 12, 1),
        title: 'MONDAY · Event',
        body: 'Deleted elsewhere',
      );
      device.pending[stale.id] = stale;

      final run = ReminderScheduler(AppStore(seedDate: seed), device,
          clock: () => now);
      await run.start();
      run.dispose();

      expect(device.pending.containsKey(stale.id), isFalse);
    });

    test('past reminders are left alone on restart', () async {
      store.updateTask(store.tasks.first, reminder: earlier);
      final device = FakeNotificationService();

      final run = ReminderScheduler(store, device, clock: () => now);
      await run.start();
      run.dispose();

      expect(device.forItem(store.tasks.first.id), isNull);
    });
  });

  group('notifications setting', () {
    test('switching off cancels every scheduled notification', () async {
      store.updateTask(store.tasks.first, reminder: later);
      await settle();
      expect(platform.pending, hasLength(2));

      store.setNotificationsEnabled(false);
      await settle();

      expect(platform.pending, isEmpty);
    });

    test('while off, new reminders and events are not scheduled', () async {
      store.setNotificationsEnabled(false);
      await settle();

      store.updateTask(store.tasks.first, reminder: later);
      store.addEvent(title: 'Dentist', start: tomorrow);
      await settle();

      expect(platform.pending, isEmpty);
    });

    test('switching back on reschedules future items only', () async {
      store.updateTask(store.tasks.first, reminder: later);
      store.updateTask(store.tasks[1], reminder: earlier);
      store.setNotificationsEnabled(false);
      await settle();

      store.setNotificationsEnabled(true);
      await settle();

      expect(platform.forItem(store.tasks.first.id)!.when, later);
      expect(platform.forItem(store.tasks[1].id), isNull);
      expect(platform.forItem(store.events.single.id), isNotNull);
    });

    test('switching back on asks for permission again', () async {
      store.setNotificationsEnabled(false);
      store.setNotificationsEnabled(true);
      await settle();

      expect(platform.permissionRequests, 1);
    });

    test('starting with notifications off schedules nothing', () async {
      final quiet = AppStore(seedDate: seed)..notificationsEnabled = false;
      final device = FakeNotificationService();

      final run = ReminderScheduler(quiet, device, clock: () => now);
      await run.start();
      run.dispose();

      expect(device.pending, isEmpty);
    });
  });

  group('permission', () {
    test('is requested once, and remembered across launches', () async {
      final storage = MemoryAppStorage();
      final device = FakeNotificationService();

      for (var launch = 0; launch < 3; launch++) {
        final launched = await AppStore.open(storage, seedDate: seed);
        final run = ReminderScheduler(launched, device, clock: () => now);
        await run.start();
        await run.requestPermissionOnce();
        await launched.flush();
        run.dispose();
      }

      expect(device.permissionRequests, 1);
    });

    test('is not requested while notifications are off', () async {
      store.setNotificationsEnabled(false);
      await settle();

      await scheduler.requestPermissionOnce();

      expect(platform.permissionRequests, 0);
      expect(store.notificationPermissionRequested, isFalse);
    });

    test('a denial does not stop tasks or events from working', () async {
      platform.grantPermission = false;
      await scheduler.requestPermissionOnce();

      final task = store.addTask(title: 'Still works');
      store.updateTask(task, reminder: later);
      final event = store.addEvent(title: 'Also works', start: tomorrow);
      await settle();

      expect(store.taskById(task.id)!.reminder, later);
      expect(store.eventById(event.id), isNotNull);
    });
  });

  test('a failing platform never breaks the store', () async {
    platform.failEverything = true;

    final task = store.tasks.first;
    store.updateTask(task, reminder: later);
    store.deleteEvent(store.events.single);
    store.setNotificationsEnabled(false);
    store.setNotificationsEnabled(true);
    await settle();

    expect(task.reminder, later);
    expect(store.events, isEmpty);

    // And it recovers once the platform does.
    platform.failEverything = false;
    store.updateTask(task, reminder: tomorrow);
    await settle();
    expect(platform.forItem(task.id)!.when, tomorrow);
  });

  group('notificationIdFor', () {
    test('is stable and distinct for store ids', () {
      expect(notificationIdFor('task_7'), notificationIdFor('task_7'));
      expect(notificationIdFor('task_7'), isNot(notificationIdFor('task_8')));
      expect(notificationIdFor('event_9'), isNot(notificationIdFor('task_7')));
    });

    test('hashes ids without a numeric suffix into the 31-bit range', () {
      final id = notificationIdFor('project_monday');
      expect(id, notificationIdFor('project_monday'));
      expect(id, inInclusiveRange(0, 0x7fffffff));
    });
  });
}
