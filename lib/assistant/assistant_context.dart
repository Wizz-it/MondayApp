import 'package:flutter/foundation.dart';

/// What a language model needs to know about "now" to interpret a request —
/// and nothing else. No store data goes in here.
///
/// Built from one reading of the clock per request. The model uses it to
/// understand the user; the app still resolves every date itself
/// ([DateResolver]), so a model that misreads the context can't move a task
/// to the wrong day without the app noticing.
@immutable
class AssistantContext {
  AssistantContext(DateTime now, {Duration? utcOffset})
      : now = now.isUtc ? now.toLocal() : now,
        utcOffset = utcOffset ?? (now.isUtc ? now.toLocal() : now).timeZoneOffset;

  /// The local moment of the request.
  final DateTime now;

  /// The device's offset from UTC at [now].
  final Duration utcOffset;

  static const _weekdays = [
    'monday', 'tuesday', 'wednesday', 'thursday',
    'friday', 'saturday', 'sunday',
  ];

  static const _weekdaysId = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  /// "2026-10-03"
  String get date => '${now.year.toString().padLeft(4, '0')}-'
      '${_two(now.month)}-${_two(now.day)}';

  /// "10:00", 24-hour.
  String get time => '${_two(now.hour)}:${_two(now.minute)}';

  /// "saturday" — the same spelling the action schema uses.
  String get weekday => _weekdays[now.weekday - 1];

  /// "Sabtu"
  String get weekdayIndonesian => _weekdaysId[now.weekday - 1];

  /// "+07:00"
  String get utcOffsetLabel {
    final sign = utcOffset.isNegative ? '-' : '+';
    final minutes = utcOffset.inMinutes.abs();
    return '$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
  }

  /// The form a provider would put into its prompt.
  Map<String, String> toJson() => {
        'date': date,
        'time': time,
        'weekday': weekday,
        'weekday_id': weekdayIndonesian,
        'utc_offset': utcOffsetLabel,
      };

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  bool operator ==(Object other) =>
      other is AssistantContext &&
      other.now == now &&
      other.utcOffset == utcOffset;

  @override
  int get hashCode => Object.hash(now, utcOffset);

  @override
  String toString() => 'AssistantContext(${toJson()})';
}
