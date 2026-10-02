import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../utils/date_labels.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/filter_chips.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';
import '../widgets/task_row.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskFilter _filter = TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final tasks = store.tasksFor(_filter);

    return MondayScreen(
      fab: MondayFab(onPressed: () => showNewTaskSheet(context)),
      children: [
        const ScreenHeader(
          eyebrow: 'MONDAY  /  TASKS',
          title: 'Tasks',
          subtitle: "The things you're moving forward.",
        ),
        const SizedBox(height: 26),
        MondayFilterChips<TaskFilter>(
          values: TaskFilter.values,
          selected: _filter,
          labelOf: (f) => f.label,
          onSelected: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: 26),
        EyebrowRow(
          label: 'YOUR TASKS',
          trailing: counterLabel(tasks.length),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          EmptyStateCard(
            icon: Icons.check_circle_outline,
            title: _emptyTitle,
            message: _emptyMessage,
            actionLabel: _filter == TaskFilter.done ? null : 'Add a task',
            onAction: () => showNewTaskSheet(context),
          )
        else
          GroupedCard(
            children: [
              for (final task in tasks)
                TaskRow(
                  task: task,
                  projectName: store.projectNameFor(task),
                  onToggle: () => store.toggleTask(task),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(taskId: task.id),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String get _emptyTitle => switch (_filter) {
        TaskFilter.all => 'Nothing on your plate',
        TaskFilter.today => 'Today is clear',
        TaskFilter.upcoming => 'Nothing scheduled yet',
        TaskFilter.done => 'Nothing finished yet',
      };

  String get _emptyMessage => switch (_filter) {
        TaskFilter.all =>
          'Add the first thing you want to move forward.',
        TaskFilter.today =>
          'No tasks are due today. Add one if something comes up.',
        TaskFilter.upcoming =>
          'Tasks with a future date will gather here.',
        TaskFilter.done =>
          'Tasks you complete will be kept here.',
      };
}
