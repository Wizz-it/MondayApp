import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// One notification the app wants the platform to show at [when].
@immutable
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime when;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ScheduledNotification &&
      other.id == id &&
      other.when == when &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, when, title, body);

  @override
  String toString() => 'ScheduledNotification($id, $when, $title, $body)';
}

/// The platform side of notifications: it shows what it is told to and knows
/// nothing about tasks or events. [ReminderScheduler] decides what to show.
abstract interface class NotificationService {
  /// Must complete before any other call.
  Future<void> initialize();

  /// Asks the user for permission to post notifications. Returns whether
  /// notifications are allowed afterwards.
  Future<bool> requestPermission();

  /// Schedules [notification], replacing any pending one with the same id.
  Future<void> schedule(ScheduledNotification notification);

  Future<void> cancel(int id);

  /// Ids of notifications scheduled but not yet shown, including ones left
  /// over from an earlier run of the app.
  Future<Set<int>> pendingIds();
}

/// A stable notification id for a task or event id.
///
/// Platform ids are 32-bit ints and must not change between launches, so
/// `String.hashCode` (which may differ per run) is not usable. Store ids are
/// `<kind>_<n>` with one counter shared by every kind, so `n` alone is unique;
/// anything else falls back to a 31-bit FNV-1a hash.
int notificationIdFor(String itemId) {
  final suffix = int.tryParse(itemId.substring(itemId.lastIndexOf('_') + 1));
  if (suffix != null && suffix >= 0 && suffix <= 0x7fffffff) return suffix;
  var hash = 0x811c9dc5;
  for (final unit in itemId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// [NotificationService] backed by `flutter_local_notifications`.
///
/// Every call is guarded: a failure here must never break task or event
/// editing, so errors are logged and the app carries on without notifications.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'monday_reminders',
    'Reminders',
    channelDescription: 'Task reminders and events as they start',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize() async {
    if (!_supported) return;
    try {
      // Permission is requested separately, once, rather than on iOS's
      // default of asking during initialization.
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
        ),
      );
      _ready = true;
    } catch (error) {
      debugPrint('MONDAY: notifications unavailable: $error');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final granted = await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    } catch (error) {
      debugPrint('MONDAY: could not request notification permission: $error');
      return false;
    }
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: notification.id,
        // An absolute instant, so no time zone database is needed.
        scheduledDate: tz.TZDateTime.from(notification.when, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: await _scheduleMode(),
        title: notification.title,
        body: notification.body,
      );
    } catch (error) {
      debugPrint('MONDAY: could not schedule notification: $error');
    }
  }

  /// Exact alarms need a permission the user grants in system settings on
  /// Android 14+. Without it, fall back to an inexact alarm, which Android
  /// may deliver a little late.
  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  @override
  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (error) {
      debugPrint('MONDAY: could not cancel notification: $error');
    }
  }

  @override
  Future<Set<int>> pendingIds() async {
    if (!_ready) return {};
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return {for (final request in pending) request.id};
    } catch (error) {
      debugPrint('MONDAY: could not read pending notifications: $error');
      return {};
    }
  }
}
