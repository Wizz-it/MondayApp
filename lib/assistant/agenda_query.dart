import 'package:flutter/foundation.dart';

import '../services/app_store.dart';
import '../utils/date_labels.dart';
import 'assistant_action.dart';

/// A task as the assistant may describe it: no ids, no store objects.
@immutable
class AgendaTask {
  const AgendaTask({required this.title, this.projectName, this.reminder});

  final String title;
  final String? projectName;
  final DateTime? reminder;

  @override
  bool operator ==(Object other) =>
      other is AgendaTask &&
      other.title == title &&
      other.projectName == projectName &&
      other.reminder == reminder;

  @override
  int get hashCode => Object.hash(title, projectName, reminder);

  @override
  String toString() => 'AgendaTask($title, $projectName, $reminder)';
}

@immutable
class AgendaEvent {
  const AgendaEvent({required this.title, required this.start});

  final String title;
  final DateTime start;

  @override
  bool operator ==(Object other) =>
      other is AgendaEvent && other.title == title && other.start == start;

  @override
  int get hashCode => Object.hash(title, start);

  @override
  String toString() => 'AgendaEvent($title, $start)';
}

/// One day's agenda, cut down to what an answer needs. This is the only shape
/// in which store data will ever be handed to future AI code.
@immutable
class AgendaSnapshot {
  const AgendaSnapshot({
    required this.day,
    required this.include,
    this.openTasks = const [],
    this.completedTaskCount = 0,
    this.events = const [],
  });

  final DateTime day;
  final Set<AgendaPart> include;
  final List<AgendaTask> openTasks;
  final int completedTaskCount;

  /// In start order.
  final List<AgendaEvent> events;

  bool get includesTasks => include.contains(AgendaPart.tasks);
  bool get includesEvents => include.contains(AgendaPart.events);
}

/// Reads a day's tasks and events through the store's existing queries.
/// Read-only; notes and inbox are never included.
class AgendaQuery {
  const AgendaQuery(this._store);

  final AppStore _store;

  AgendaSnapshot forDay(DateTime day, {required Set<AgendaPart> include}) {
    final date = dayOf(day);
    final wantsTasks = include.contains(AgendaPart.tasks);
    final tasks = wantsTasks ? _store.tasksOn(date) : const [];

    return AgendaSnapshot(
      day: date,
      include: Set.unmodifiable(include),
      openTasks: List.unmodifiable([
        for (final task in tasks)
          if (!task.isDone)
            AgendaTask(
              title: task.title,
              projectName: _store.projectNameFor(task),
              reminder: task.reminder,
            ),
      ]),
      completedTaskCount: tasks.where((t) => t.isDone).length,
      events: List.unmodifiable([
        if (include.contains(AgendaPart.events))
          for (final event in _store.eventsOn(date))
            AgendaEvent(title: event.title, start: event.start),
      ]),
    );
  }
}
