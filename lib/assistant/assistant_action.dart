import 'package:flutter/foundation.dart';

/// What the assistant has been asked to do, as reported by the language model
/// (in future) and before the app has checked or resolved anything.
///
/// These are plain values: they carry what the user *said* ("besok", "jam 2",
/// a project *name*) and never anything the app would have to trust, such as
/// ids or absolute timestamps. [ActionParser] builds them; [ActionValidator]
/// turns them into something executable.
sealed class AssistantAction {
  const AssistantAction();
}

@immutable
final class CreateTask extends AssistantAction {
  const CreateTask({
    required this.title,
    this.date,
    this.time,
    this.project,
  });

  final String title;
  final DateRef? date;
  final TimeRef? time;

  /// A project *name* as spoken. Matched against existing projects later;
  /// never used to create one.
  final String? project;

  @override
  bool operator ==(Object other) =>
      other is CreateTask &&
      other.title == title &&
      other.date == date &&
      other.time == time &&
      other.project == project;

  @override
  int get hashCode => Object.hash(CreateTask, title, date, time, project);

  @override
  String toString() => 'CreateTask($title, $date, $time, project: $project)';
}

@immutable
final class CreateEvent extends AssistantAction {
  const CreateEvent({
    required this.title,
    this.date,
    this.time,
    this.description,
  });

  final String title;

  /// Required for an event, but may be missing from what the user said; the
  /// validator asks for it rather than the parser refusing the request.
  final DateRef? date;
  final TimeRef? time;
  final String? description;

  @override
  bool operator ==(Object other) =>
      other is CreateEvent &&
      other.title == title &&
      other.date == date &&
      other.time == time &&
      other.description == description;

  @override
  int get hashCode => Object.hash(CreateEvent, title, date, time, description);

  @override
  String toString() => 'CreateEvent($title, $date, $time, $description)';
}

@immutable
final class CreateNote extends AssistantAction {
  const CreateNote({required this.title, this.body = ''});

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is CreateNote && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(CreateNote, title, body);

  @override
  String toString() => 'CreateNote($title, $body)';
}

@immutable
final class CaptureInbox extends AssistantAction {
  const CaptureInbox({required this.text});

  final String text;

  @override
  bool operator ==(Object other) => other is CaptureInbox && other.text == text;

  @override
  int get hashCode => Object.hash(CaptureInbox, text);

  @override
  String toString() => 'CaptureInbox($text)';
}

/// The parts of a day's agenda a query can ask about.
enum AgendaPart { tasks, events }

@immutable
final class QueryAgenda extends AssistantAction {
  const QueryAgenda({required this.date, required this.include});

  final DateRef date;
  final Set<AgendaPart> include;

  @override
  bool operator ==(Object other) =>
      other is QueryAgenda &&
      other.date == date &&
      setEquals(other.include, include);

  @override
  int get hashCode =>
      Object.hash(QueryAgenda, date, Object.hashAllUnordered(include));

  @override
  String toString() => 'QueryAgenda($date, $include)';
}

/// The model needs more information before it can propose anything.
@immutable
final class Clarify extends AssistantAction {
  const Clarify({required this.question});

  final String question;

  @override
  bool operator ==(Object other) =>
      other is Clarify && other.question == question;

  @override
  int get hashCode => Object.hash(Clarify, question);

  @override
  String toString() => 'Clarify($question)';
}

/// Why a request could not become one of the supported actions.
enum UnsupportedKind {
  /// The model itself said the request is out of scope.
  declined,

  /// Changing, completing or deleting existing data. Deliberately not
  /// available to the assistant yet.
  destructive,

  /// A recognised action the assistant does not offer yet (for example
  /// querying notes).
  notSupportedYet,

  /// An action name nobody knows.
  unknownAction,

  /// The payload did not match the schema.
  malformed,
}

@immutable
final class Unsupported extends AssistantAction {
  const Unsupported(this.kind, this.reason);

  final UnsupportedKind kind;

  /// For logs and debugging; never shown to the user as-is.
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is Unsupported && other.kind == kind && other.reason == reason;

  @override
  int get hashCode => Object.hash(Unsupported, kind, reason);

  @override
  String toString() => 'Unsupported(${kind.name}: $reason)';
}

// Date and time references --------------------------------------------------

/// A day as the user described it. [DateResolver] turns it into a date.
sealed class DateRef {
  const DateRef();
}

enum RelativeDay {
  today(0),
  tomorrow(1),
  dayAfterTomorrow(2);

  const RelativeDay(this.offset);

  /// Days after today.
  final int offset;
}

/// "hari ini", "besok", "lusa".
@immutable
final class RelativeDateRef extends DateRef {
  const RelativeDateRef(this.day);

  final RelativeDay day;

  @override
  bool operator ==(Object other) =>
      other is RelativeDateRef && other.day == day;

  @override
  int get hashCode => Object.hash(RelativeDateRef, day);

  @override
  String toString() => 'RelativeDateRef(${day.name})';
}

/// "Jumat", or with [nextWeek] "Jumat depan".
@immutable
final class WeekdayDateRef extends DateRef {
  const WeekdayDateRef(this.weekday, {this.nextWeek = false})
      : assert(weekday >= DateTime.monday && weekday <= DateTime.sunday);

  /// [DateTime.monday] .. [DateTime.sunday].
  final int weekday;
  final bool nextWeek;

  @override
  bool operator ==(Object other) =>
      other is WeekdayDateRef &&
      other.weekday == weekday &&
      other.nextWeek == nextWeek;

  @override
  int get hashCode => Object.hash(WeekdayDateRef, weekday, nextWeek);

  @override
  String toString() =>
      'WeekdayDateRef($weekday${nextWeek ? ', next week' : ''})';
}

/// "tanggal 12 Oktober", optionally with a year. Values are kept as said;
/// whether they form a real date is checked during resolution.
@immutable
final class CalendarDateRef extends DateRef {
  const CalendarDateRef({required this.day, required this.month, this.year});

  final int day;
  final int month;
  final int? year;

  @override
  bool operator ==(Object other) =>
      other is CalendarDateRef &&
      other.day == day &&
      other.month == month &&
      other.year == year;

  @override
  int get hashCode => Object.hash(CalendarDateRef, day, month, year);

  @override
  String toString() => 'CalendarDateRef($day/$month/${year ?? '-'})';
}

/// Indonesian parts of the day, as spoken.
enum Daypart { pagi, siang, sore, malam }

/// A time as the user said it: "jam 7 malam" is hour 7 with [Daypart.malam],
/// not 19:00. With no [hour], the daypart alone ("besok pagi") applies.
@immutable
class TimeRef {
  const TimeRef({this.hour, this.minute, this.daypart});

  final int? hour;
  final int? minute;
  final Daypart? daypart;

  @override
  bool operator ==(Object other) =>
      other is TimeRef &&
      other.hour == hour &&
      other.minute == minute &&
      other.daypart == daypart;

  @override
  int get hashCode => Object.hash(TimeRef, hour, minute, daypart);

  @override
  String toString() => 'TimeRef($hour:${minute ?? 0} ${daypart?.name ?? ''})';
}
