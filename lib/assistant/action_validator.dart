import 'package:flutter/foundation.dart';

import '../services/app_store.dart';
import 'assistant_action.dart';
import 'date_resolver.dart';

// Resolved actions ----------------------------------------------------------

/// An action that has been checked and resolved against the store and the
/// clock: real dates, a project id the app looked up itself, trimmed text.
/// Only [ActionExecutor] acts on these.
sealed class ResolvedAction {
  const ResolvedAction();
}

@immutable
final class ResolvedTask extends ResolvedAction {
  const ResolvedTask({
    required this.title,
    this.dueDate,
    this.reminder,
    this.projectId,
    this.projectName,
    this.unmatchedProject,
  });

  final String title;

  /// Local midnight of the due day; tasks have no time of their own.
  final DateTime? dueDate;

  /// A spoken time becomes a reminder on the due day.
  final DateTime? reminder;
  final String? projectId;
  final String? projectName;

  /// A project the user named that does not exist. Such a task is only ever
  /// offered for confirmation ([ConfirmationReason.unknownProject]) and, if
  /// accepted, created without a project. No project is ever created.
  final String? unmatchedProject;

  @override
  bool operator ==(Object other) =>
      other is ResolvedTask &&
      other.title == title &&
      other.dueDate == dueDate &&
      other.reminder == reminder &&
      other.projectId == projectId &&
      other.projectName == projectName &&
      other.unmatchedProject == unmatchedProject;

  @override
  int get hashCode => Object.hash(
      title, dueDate, reminder, projectId, projectName, unmatchedProject);

  @override
  String toString() => 'ResolvedTask($title, due: $dueDate, '
      'reminder: $reminder, project: $projectId, unmatched: $unmatchedProject)';
}

@immutable
final class ResolvedEvent extends ResolvedAction {
  const ResolvedEvent({
    required this.title,
    required this.start,
    this.description = '',
  });

  final String title;
  final DateTime start;
  final String description;

  @override
  bool operator ==(Object other) =>
      other is ResolvedEvent &&
      other.title == title &&
      other.start == start &&
      other.description == description;

  @override
  int get hashCode => Object.hash(title, start, description);

  @override
  String toString() => 'ResolvedEvent($title, $start, $description)';
}

@immutable
final class ResolvedNote extends ResolvedAction {
  const ResolvedNote({required this.title, this.body = ''});

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ResolvedNote && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);

  @override
  String toString() => 'ResolvedNote($title, $body)';
}

@immutable
final class ResolvedInboxCapture extends ResolvedAction {
  const ResolvedInboxCapture(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is ResolvedInboxCapture && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'ResolvedInboxCapture($text)';
}

@immutable
final class ResolvedAgendaQuery extends ResolvedAction {
  const ResolvedAgendaQuery({required this.day, required this.include});

  final DateTime day;
  final Set<AgendaPart> include;

  @override
  bool operator ==(Object other) =>
      other is ResolvedAgendaQuery &&
      other.day == day &&
      setEquals(other.include, include);

  @override
  int get hashCode => Object.hash(day, Object.hashAllUnordered(include));

  @override
  String toString() => 'ResolvedAgendaQuery($day, $include)';
}

// Validation results --------------------------------------------------------

sealed class ValidationResult {
  const ValidationResult();
}

/// Safe to execute as it stands.
final class Ready extends ValidationResult {
  const Ready(this.action);

  final ResolvedAction action;
}

enum ConfirmationReason {
  /// The user named a project that does not exist; [NeedsConfirmation.action]
  /// is the task without a project.
  unknownProject,

  /// The resolved time has already passed.
  pastTime,

  /// The resolved day has already passed (only possible with an explicit
  /// year).
  pastDay,
}

/// Executable, but only once the user has accepted [action] as it stands.
/// Every reason is listed, so a single question can cover all of them.
final class NeedsConfirmation extends ValidationResult {
  const NeedsConfirmation(this.reasons, this.action)
      : assert(reasons.length > 0);

  /// In the order they should be mentioned.
  final List<ConfirmationReason> reasons;
  final ResolvedAction action;
}

enum ClarificationReason {
  /// The model asked a question of its own.
  askedByAssistant,
  missingEventDate,
  missingEventTime,

  /// "jam 2" could be 02:00 or 14:00; [NeedsClarification.timeOptions] holds
  /// both readings for the question.
  ambiguousTime,

  /// The part of the day can't modify the hour ("jam 9 sore").
  unclearTime,
}

/// Nothing to execute until the user answers a question. Deliberately carries
/// no executable action: the answer comes back as a new request and is
/// checked again from the start.
final class NeedsClarification extends ValidationResult {
  const NeedsClarification(
    this.reason, {
    this.question,
    this.timeOptions = const [],
  });

  final ClarificationReason reason;

  /// The model's own question, for [ClarificationReason.askedByAssistant].
  final String? question;

  /// The possible readings, for [ClarificationReason.ambiguousTime].
  final List<ClockTime> timeOptions;
}

enum RejectionReason {
  emptyTitle,
  emptyText,
  invalidDate,
  invalidTime,

  /// Changing, completing or deleting data.
  destructive,
  notSupportedYet,
  outOfScope,
  notUnderstood,
}

/// Cannot be executed; the reply explains why.
final class Rejected extends ValidationResult {
  const Rejected(this.reason, {this.detail});

  final RejectionReason reason;

  /// For logs and debugging; not shown to the user.
  final String? detail;
}

// Validator -----------------------------------------------------------------

/// Checks an [AssistantAction] against the rules of the existing forms and
/// the store, and resolves its dates against the clock.
///
/// Reads the store (only to look projects up by name) and never writes to it.
/// Text rules match the creation sheets: titles and inbox text are trimmed and
/// must not be empty; a note body may be.
class ActionValidator {
  ActionValidator(this._store, {Clock? clock}) : _clock = clock ?? DateTime.now;

  final AppStore _store;
  final Clock _clock;

  ValidationResult validate(AssistantAction action) {
    // One reading of the clock for the whole request.
    final dates = DateResolver(_clock());
    return switch (action) {
      CreateTask() => _task(action, dates),
      CreateEvent() => _event(action, dates),
      CreateNote() => _note(action),
      CaptureInbox() => _inbox(action),
      QueryAgenda() => _query(action, dates),
      Clarify(:final question) => NeedsClarification(
          ClarificationReason.askedByAssistant,
          question: question,
        ),
      Unsupported() => _unsupported(action),
    };
  }

  ValidationResult _task(CreateTask action, DateResolver dates) {
    final title = action.title.trim();
    if (title.isEmpty) return const Rejected(RejectionReason.emptyTitle);

    final (time, problem) = _time(action.time, dates);
    if (problem != null) return problem;

    // A time on its own ("jam 7") means today.
    final dateRef = action.date ??
        (time == null ? null : const RelativeDateRef(RelativeDay.today));

    DateTime? day;
    if (dateRef != null) {
      switch (dates.resolveDay(dateRef, at: time)) {
        case InvalidDay(:final reason):
          return Rejected(RejectionReason.invalidDate, detail: reason);
        case ResolvedDay(day: final resolved):
          day = resolved;
      }
    }

    final spokenProject = _spoken(action.project);
    final project = _project(spokenProject);
    final task = ResolvedTask(
      title: title,
      dueDate: day,
      reminder: day == null || time == null ? null : time.on(day),
      projectId: project?.id,
      projectName: project?.name,
      unmatchedProject: project == null ? spokenProject : null,
    );

    final reasons = [
      if (task.unmatchedProject != null) ConfirmationReason.unknownProject,
      if (task.reminder != null && task.reminder!.isBefore(dates.now))
        ConfirmationReason.pastTime
      else if (task.dueDate != null && task.dueDate!.isBefore(dates.today))
        ConfirmationReason.pastDay,
    ];
    return reasons.isEmpty ? Ready(task) : NeedsConfirmation(reasons, task);
  }

  ValidationResult _event(CreateEvent action, DateResolver dates) {
    final title = action.title.trim();
    if (title.isEmpty) return const Rejected(RejectionReason.emptyTitle);

    final dateRef = action.date;
    if (dateRef == null) {
      return const NeedsClarification(ClarificationReason.missingEventDate);
    }
    final (time, problem) = _time(action.time, dates);
    if (problem != null) return problem;
    if (time == null) {
      return const NeedsClarification(ClarificationReason.missingEventTime);
    }

    final DateTime day;
    switch (dates.resolveDay(dateRef, at: time)) {
      case InvalidDay(:final reason):
        return Rejected(RejectionReason.invalidDate, detail: reason);
      case ResolvedDay(day: final resolved):
        day = resolved;
    }

    final event = ResolvedEvent(
      title: title,
      start: time.on(day),
      description: action.description?.trim() ?? '',
    );
    if (event.start.isBefore(dates.now)) {
      return NeedsConfirmation(const [ConfirmationReason.pastTime], event);
    }
    return Ready(event);
  }

  ValidationResult _note(CreateNote action) {
    final title = action.title.trim();
    if (title.isEmpty) return const Rejected(RejectionReason.emptyTitle);
    return Ready(ResolvedNote(title: title, body: action.body.trim()));
  }

  ValidationResult _inbox(CaptureInbox action) {
    final text = action.text.trim();
    if (text.isEmpty) return const Rejected(RejectionReason.emptyText);
    return Ready(ResolvedInboxCapture(text));
  }

  ValidationResult _query(QueryAgenda action, DateResolver dates) {
    return switch (dates.resolveDay(action.date)) {
      InvalidDay(:final reason) =>
        Rejected(RejectionReason.invalidDate, detail: reason),
      ResolvedDay(:final day) =>
        Ready(ResolvedAgendaQuery(day: day, include: action.include)),
    };
  }

  ValidationResult _unsupported(Unsupported action) {
    final reason = switch (action.kind) {
      UnsupportedKind.declined => RejectionReason.outOfScope,
      UnsupportedKind.destructive => RejectionReason.destructive,
      UnsupportedKind.notSupportedYet => RejectionReason.notSupportedYet,
      UnsupportedKind.unknownAction ||
      UnsupportedKind.malformed =>
        RejectionReason.notUnderstood,
    };
    return Rejected(reason, detail: action.reason);
  }

  /// The exact time [time] stands for: null when no time was given, or a
  /// [ValidationResult] when it can't be used as it stands.
  (ClockTime?, ValidationResult?) _time(TimeRef? time, DateResolver dates) {
    if (time == null) return (null, null);
    return switch (dates.resolveTime(time)) {
      ExactTime(:final time) => (time, null),
      AmbiguousTime(:final readings) => (
          null,
          NeedsClarification(
            ClarificationReason.ambiguousTime,
            timeOptions: readings,
          ),
        ),
      UnclearTime() => (
          null,
          const NeedsClarification(ClarificationReason.unclearTime),
        ),
      InvalidTime(:final reason) => (
          null,
          Rejected(RejectionReason.invalidTime, detail: reason),
        ),
    };
  }

  /// The existing project whose name matches [spoken] exactly, ignoring case
  /// and surrounding spaces. The id comes from the store, never the action.
  ({String id, String name})? _project(String? spoken) {
    final wanted = spoken?.toLowerCase();
    if (wanted == null) return null;
    for (final project in _store.projects) {
      if (project.name.trim().toLowerCase() == wanted) {
        return (id: project.id, name: project.name);
      }
    }
    return null;
  }

  static String? _spoken(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
