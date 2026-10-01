import 'tile_tint.dart';

enum TaskPriority {
  low('Low'),
  normal('Normal'),
  high('High');

  const TaskPriority(this.label);
  final String label;
}

class Task {
  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.projectId,
    this.dueDate,
    this.reminder,
    this.priority = TaskPriority.normal,
    this.isDone = false,
  });

  final String id;
  String title;
  String description;
  String? projectId;
  DateTime? dueDate;
  DateTime? reminder;
  TaskPriority priority;
  bool isDone;

  /// Tasks inherit their project's tint; unassigned tasks fall back to sage.
  TileTint get tint => TileTint.sage;
}
