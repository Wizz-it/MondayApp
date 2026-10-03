import 'dart:convert';

import 'assistant_action.dart';

/// Turns one structured action, as a language model would return it, into an
/// [AssistantAction].
///
/// Strict on purpose: the schema has no optional extras, so an unexpected key,
/// a wrong type or a field that does not belong to the action makes the whole
/// payload [UnsupportedKind.malformed]. That also rules out ids — no action
/// carries one, so any id field is rejected. Nothing here executes anything,
/// and [parse] never throws.
class ActionParser {
  const ActionParser();

  /// Actions that change or remove existing data. Recognised so they can be
  /// refused clearly, but not available to the assistant.
  static const _destructivePrefixes = ['update_', 'delete_', 'complete_'];

  /// Recognised, harmless, but not offered yet.
  static const _notYet = {
    'query_tasks',
    'query_events',
    'query_projects',
    'query_notes',
    'query_inbox',
  };

  /// Parses raw model output text.
  AssistantAction parseJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      return Unsupported(UnsupportedKind.malformed, 'not JSON: ${error.message}');
    }
    return parse(decoded);
  }

  /// Parses an already-decoded JSON value.
  AssistantAction parse(Object? json) {
    try {
      return _parse(json);
    } on _Malformed catch (problem) {
      return Unsupported(UnsupportedKind.malformed, problem.message);
    }
  }

  AssistantAction _parse(Object? json) {
    final map = _object(json, 'action payload');
    final action = map['action'];
    if (action is! String) throw const _Malformed('"action" must be a string');

    switch (action) {
      case 'create_task':
        _only(map, {'action', 'title', 'date', 'time', 'project'});
        return CreateTask(
          title: _string(map, 'title'),
          date: _optionalDate(map, 'date'),
          time: _optionalTime(map, 'time'),
          project: _optionalString(map, 'project'),
        );
      case 'create_event':
        _only(map, {'action', 'title', 'date', 'time', 'description'});
        return CreateEvent(
          title: _string(map, 'title'),
          date: _optionalDate(map, 'date'),
          time: _optionalTime(map, 'time'),
          description: _optionalString(map, 'description'),
        );
      case 'create_note':
        _only(map, {'action', 'title', 'body'});
        return CreateNote(
          title: _string(map, 'title'),
          body: _optionalString(map, 'body') ?? '',
        );
      case 'capture_inbox':
        _only(map, {'action', 'text'});
        return CaptureInbox(text: _string(map, 'text'));
      case 'query_agenda':
        _only(map, {'action', 'date', 'include'});
        final date = _optionalDate(map, 'date');
        if (date == null) throw const _Malformed('"date" is required');
        return QueryAgenda(date: date, include: _include(map['include']));
      case 'clarify':
        _only(map, {'action', 'question'});
        return Clarify(question: _string(map, 'question'));
      case 'unsupported':
        _only(map, {'action', 'reason'});
        return Unsupported(UnsupportedKind.declined, _string(map, 'reason'));
    }

    if (_destructivePrefixes.any(action.startsWith)) {
      return Unsupported(UnsupportedKind.destructive, action);
    }
    if (_notYet.contains(action)) {
      return Unsupported(UnsupportedKind.notSupportedYet, action);
    }
    return Unsupported(UnsupportedKind.unknownAction, action);
  }

  // Dates and times ---------------------------------------------------------

  static const _weekdays = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  DateRef? _optionalDate(Map<String, Object?> parent, String key) {
    final value = parent[key];
    if (value == null) return null;
    final map = _object(value, key);
    _only(map, {'kind', 'weekday', 'next_week', 'day', 'month', 'year'});

    final kind = _string(map, 'kind');
    final nextWeek = _optionalBool(map, 'next_week') ?? false;
    final weekday = _optionalString(map, 'weekday');
    final day = _optionalInt(map, 'day');
    final month = _optionalInt(map, 'month');
    final year = _optionalInt(map, 'year');

    void noneOf(List<(String, Object?)> fields) {
      for (final (name, value) in fields) {
        if (value != null) {
          throw _Malformed('"$name" does not apply to a "$kind" date');
        }
      }
    }

    if (kind != 'weekday' && nextWeek) {
      throw _Malformed('"next_week" does not apply to a "$kind" date');
    }

    switch (kind) {
      case 'today' || 'tomorrow' || 'day_after_tomorrow':
        noneOf([('weekday', weekday), ('day', day), ('month', month), ('year', year)]);
        return RelativeDateRef(switch (kind) {
          'today' => RelativeDay.today,
          'tomorrow' => RelativeDay.tomorrow,
          _ => RelativeDay.dayAfterTomorrow,
        });
      case 'weekday':
        noneOf([('day', day), ('month', month), ('year', year)]);
        final number = _weekdays[weekday];
        if (number == null) throw _Malformed('unknown weekday "$weekday"');
        return WeekdayDateRef(number, nextWeek: nextWeek);
      case 'calendar_date':
        noneOf([('weekday', weekday)]);
        if (day == null || month == null) {
          throw const _Malformed('a calendar date needs "day" and "month"');
        }
        return CalendarDateRef(day: day, month: month, year: year);
    }
    throw _Malformed('unknown date kind "$kind"');
  }

  TimeRef? _optionalTime(Map<String, Object?> parent, String key) {
    final value = parent[key];
    if (value == null) return null;
    final map = _object(value, key);
    _only(map, {'hour', 'minute', 'daypart'});

    final hour = _optionalInt(map, 'hour');
    final minute = _optionalInt(map, 'minute');
    final daypartName = _optionalString(map, 'daypart');
    final daypart = daypartName == null
        ? null
        : Daypart.values.asNameMap()[daypartName] ??
            (throw _Malformed('unknown daypart "$daypartName"'));

    if (hour == null && daypart == null) {
      throw const _Malformed('a time needs an "hour" or a "daypart"');
    }
    if (hour == null && minute != null) {
      throw const _Malformed('"minute" needs an "hour"');
    }
    // Ranges are checked during resolution, so an impossible time is reported
    // as an invalid time rather than as a broken payload.
    return TimeRef(hour: hour, minute: minute, daypart: daypart);
  }

  Set<AgendaPart> _include(Object? value) {
    if (value is! List || value.isEmpty) {
      throw const _Malformed('"include" must be a non-empty list');
    }
    final parts = <AgendaPart>{};
    for (final item in value) {
      final part = item is String ? AgendaPart.values.asNameMap()[item] : null;
      if (part == null) throw _Malformed('unknown agenda part "$item"');
      parts.add(part);
    }
    return parts;
  }

  // Primitive checks --------------------------------------------------------

  Map<String, Object?> _object(Object? value, String name) {
    if (value is! Map) throw _Malformed('$name must be an object');
    if (value.keys.any((key) => key is! String)) {
      throw _Malformed('$name has non-string keys');
    }
    return value.cast<String, Object?>();
  }

  void _only(Map<String, Object?> map, Set<String> allowed) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) throw _Malformed('unexpected field "$key"');
    }
  }

  String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String) throw _Malformed('"$key" must be a string');
    return value;
  }

  String? _optionalString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != null && value is! String) {
      throw _Malformed('"$key" must be a string or null');
    }
    return value as String?;
  }

  int? _optionalInt(Map<String, Object?> map, String key) {
    final value = map[key];
    // JSON has one number type; only whole numbers written as integers count.
    if (value != null && value is! int) {
      throw _Malformed('"$key" must be an integer or null');
    }
    return value as int?;
  }

  bool? _optionalBool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != null && value is! bool) {
      throw _Malformed('"$key" must be a boolean or null');
    }
    return value as bool?;
  }
}

class _Malformed implements Exception {
  const _Malformed(this.message);

  final String message;
}
