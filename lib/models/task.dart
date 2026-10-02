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

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        projectId: json['projectId'] as String?,
        dueDate: _parseDate(json['dueDate']),
        reminder: _parseDate(json['reminder']),
        priority: TaskPriority.values.asNameMap()[json['priority']] ??
            TaskPriority.normal,
        isDone: json['isDone'] as bool? ?? false,
      );

  final String id;
  String title;
  String description;
  String? projectId;
  DateTime? dueDate;
  DateTime? reminder;
  TaskPriority priority;
  bool isDone;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'projectId': projectId,
        'dueDate': dueDate?.toIso8601String(),
        'reminder': reminder?.toIso8601String(),
        'priority': priority.name,
        'isDone': isDone,
      };

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  /// Tasks inherit their project's tint; unassigned tasks fall back to sage.
  TileTint get tint => TileTint.sage;
}
