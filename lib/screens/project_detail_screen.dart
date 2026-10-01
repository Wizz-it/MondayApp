import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';
import '../widgets/task_row.dart';
import 'task_detail_screen.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final tasks = store.tasksForProject(project.id);

    return MondayScreen(
      showBack: true,
      fab: MondayFab(
        onPressed: () => showNewTaskSheet(context, projectId: project.id),
      ),
      children: [
        ScreenHeader(
          eyebrow: 'PROJECT',
          title: project.name,
          subtitle: project.description.isEmpty ? null : project.description,
          titleStyle: MondayType.displaySoft,
        ),
        const SizedBox(height: 30),
        EyebrowRow(
          label: 'RELATED TASKS',
          trailing: counterLabel(tasks.length),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          EmptyStateCard(
            icon: Icons.check_circle_outline,
            title: 'No tasks here yet',
            message: 'Everything you add to this project will show up here.',
            actionLabel: 'Add a task',
            onAction: () => showNewTaskSheet(context, projectId: project.id),
          )
        else
          GroupedCard(
            children: [
              for (final task in tasks)
                TaskRow(
                  task: task,
                  projectName: project.name,
                  onToggle: () => store.toggleTask(task),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(task: task),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _confirmDelete(context, store),
            icon: Icon(Icons.delete_outline, size: 18, color: p.danger),
            label: Text(
              'Delete project',
              style: MondayType.rowTitle.copyWith(color: p.danger),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppStore store) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          'Tasks in ${project.name} will be kept, but they will no longer '
          'belong to a project.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      store.deleteProject(project);
      navigator.pop();
    }
  }
}
