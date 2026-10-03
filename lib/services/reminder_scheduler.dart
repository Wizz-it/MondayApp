import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/date_labels.dart';
import 'app_store.dart';
import 'notification_service.dart';

/// Keeps the platform's scheduled notifications in line with the [AppStore].
///
/// The store stays the only source of truth. After every store change this
/// works out which notifications should exist — open tasks with a reminder,
/// and every event at its start — compares that with what it scheduled last
/// time, and only cancels or schedules the difference. That covers every way a
/// reminder can change (edited, cleared, task completed or deleted, event
/// moved or deleted, notifications switched off) without each store method
/// having to know about notifications.
class ReminderScheduler {
  ReminderScheduler(
    this._store,
    this._notifications, {
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final AppStore _store;
  final NotificationService _notifications;
  final DateTime Function() _now;

  /// What should be scheduled as of the last sync, keyed by notification id.
  /// Includes items whose time has passed, so that merely passing a reminder
  /// time is not mistaken for a change (cancelling would also clear the
  /// notification the user is looking at).
  Map<int, ScheduledNotification> _wanted = {};
  bool _enabled = false;
  bool _started = false;

  /// Platform calls run one at a time, in order, so a cancel can never
  /// overtake the schedule it is meant to undo.
  Future<void> _queue = Future.value();

  /// Completes once every platform call queued so far has finished.
  Future<void> get idle => _queue;

  /// Reconciles with whatever the platform still has from an earlier run, then
  /// follows the store. Scheduling an id that is already pending replaces it,
  /// so restarting never creates duplicates.
  Future<void> start() {
    assert(!_started, 'ReminderScheduler.start() called twice');
    _started = true;
    _wanted = _wantedNow();
    _enabled = _store.notificationsEnabled;
    _store.addListener(_sync);

    final wanted = _wanted;
    _enqueue(() async {
      for (final id in await _notifications.pendingIds()) {
        if (!wanted.containsKey(id)) await _notifications.cancel(id);
      }
      for (final notification in wanted.values) {
        if (_isFuture(notification)) {
          await _notifications.schedule(notification);
        }
      }
    });
    return idle;
  }

  /// Asks for notification permission the first time the app runs with
  /// notifications on, and never again on later launches.
  Future<void> requestPermissionOnce() async {
    if (!_store.notificationsEnabled ||
        _store.notificationPermissionRequested) {
      return;
    }
    _store.markNotificationPermissionRequested();
    await _notifications.requestPermission();
  }

  void dispose() {
    if (_started) _store.removeListener(_sync);
  }

  void _sync() {
    final previous = _wanted;
    final wanted = _wantedNow();
    _wanted = wanted;

    // Turning notifications back on is a deliberate choice, so it is the one
    // other moment worth asking for permission. Android shows nothing if the
    // user has already said no for good.
    final enabled = _store.notificationsEnabled;
    if (enabled && !_enabled) _enqueue(_notifications.requestPermission);
    _enabled = enabled;

    for (final entry in previous.entries) {
      if (wanted[entry.key] != entry.value) {
        _enqueue(() => _notifications.cancel(entry.key));
      }
    }
    for (final notification in wanted.values) {
      if (previous[notification.id] != notification &&
          _isFuture(notification)) {
        _enqueue(() => _notifications.schedule(notification));
      }
    }
  }

  Map<int, ScheduledNotification> _wantedNow() {
    if (!_store.notificationsEnabled) return {};
    final wanted = <int, ScheduledNotification>{};
    for (final task in _store.tasks) {
      final reminder = task.reminder;
      if (task.isDone || reminder == null) continue;
      final id = notificationIdFor(task.id);
      wanted[id] = ScheduledNotification(
        id: id,
        when: reminder,
        title: 'MONDAY · Task reminder',
        body: task.title,
      );
    }
    for (final event in _store.events) {
      final id = notificationIdFor(event.id);
      wanted[id] = ScheduledNotification(
        id: id,
        when: event.start,
        title: 'MONDAY · Event',
        body: '${event.title} · ${timeLabel(event.start)}',
      );
    }
    return wanted;
  }

  bool _isFuture(ScheduledNotification notification) =>
      notification.when.isAfter(_now());

  void _enqueue(Future<void> Function() call) {
    _queue = _queue.then((_) => call()).catchError(
          (Object error) => debugPrint('MONDAY: notification call failed: $error'),
        );
  }
}
