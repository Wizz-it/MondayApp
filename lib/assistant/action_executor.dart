import '../services/app_store.dart';
import 'action_validator.dart';
import 'agenda_query.dart';

/// What happened when a resolved action ran. Carries ids of created items so
/// a later controller can offer Undo; these never go to the AI.
sealed class ExecutionResult {
  const ExecutionResult();
}

final class TaskCreated extends ExecutionResult {
  const TaskCreated({
    required this.taskId,
    required this.title,
    this.dueDate,
    this.reminder,
    this.projectName,
    this.unmatchedProject,
  });

  final String taskId;
  final String title;
  final DateTime? dueDate;
  final DateTime? reminder;
  final String? projectName;
  final String? unmatchedProject;
}

final class EventCreated extends ExecutionResult {
  const EventCreated({
    required this.eventId,
    required this.title,
    required this.start,
  });

  final String eventId;
  final String title;
  final DateTime start;
}

final class NoteCreated extends ExecutionResult {
  const NoteCreated({required this.noteId, required this.title});

  final String noteId;
  final String title;
}

final class InboxCaptured extends ExecutionResult {
  const InboxCaptured({required this.itemId, required this.text});

  final String itemId;
  final String text;
}

final class AgendaAnswered extends ExecutionResult {
  const AgendaAnswered(this.agenda);

  final AgendaSnapshot agenda;
}

/// The only assistant class that writes, and it writes only through the
/// store's existing methods — so persistence and notification scheduling
/// (which follows the store) work exactly as they do for the forms.
///
/// Takes [ResolvedAction]s only: the output of [ActionValidator], either
/// directly ([Ready]) or after the user picked a confirmation candidate.
class ActionExecutor {
  const ActionExecutor(this._store);

  final AppStore _store;

  ExecutionResult execute(ResolvedAction action) {
    switch (action) {
      case ResolvedTask():
        final task = _store.addTask(
          title: action.title,
          dueDate: action.dueDate,
          projectId: action.projectId,
        );
        // Tasks have a due day and a separate reminder; the form sets the
        // reminder the same way, through updateTask.
        if (action.reminder != null) {
          _store.updateTask(task, reminder: action.reminder);
        }
        return TaskCreated(
          taskId: task.id,
          title: task.title,
          dueDate: task.dueDate,
          reminder: task.reminder,
          projectName: action.projectName,
          unmatchedProject: action.unmatchedProject,
        );

      case ResolvedEvent():
        final event = _store.addEvent(
          title: action.title,
          start: action.start,
          description: action.description,
        );
        return EventCreated(
          eventId: event.id,
          title: event.title,
          start: event.start,
        );

      case ResolvedNote():
        final note = _store.addNote(title: action.title, body: action.body);
        return NoteCreated(noteId: note.id, title: note.title);

      case ResolvedInboxCapture():
        final item = _store.captureThought(action.text);
        return InboxCaptured(itemId: item.id, text: item.text);

      case ResolvedAgendaQuery(:final day, :final include):
        return AgendaAnswered(
          AgendaQuery(_store).forDay(day, include: include),
        );
    }
  }
}
