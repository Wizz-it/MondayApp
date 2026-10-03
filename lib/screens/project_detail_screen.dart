import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/tile_tint.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/grouped_card.dart';
import '../widgets/icon_tile.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/monday_sheet.dart';
import '../widgets/screen_header.dart';
import '../widgets/task_row.dart';
import 'task_detail_screen.dart';

/// Asks before deleting [project]; its tasks are kept but unassigned.
/// Returns whether the project was deleted.
Future<bool> confirmDeleteProject(BuildContext context, Project project) async {
  final store = AppScope.read(context);
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
  if (!(confirmed ?? false)) return false;
  store.deleteProject(project);
  return true;
}

/// Project detail. Addressed by id, like the task and event detail screens,
/// so it always shows the store's current version and notices a deletion.
class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final project = store.projectById(projectId);

    if (project == null) {
      return const MondayScreen(
        showBack: true,
        children: [
          ScreenHeader(
            eyebrow: 'PROJECT',
            title: 'Project removed',
            subtitle: 'This project is no longer in your workspace.',
          ),
        ],
      );
    }

    final tasks = store.tasksForProject(project.id);

    return MondayScreen(
      showBack: true,
      headerAction: MondayCircleButton(
        icon: Icons.edit_outlined,
        size: 42,
        background: p.surface,
        foreground: p.ink,
        onPressed: () => showEditProjectSheet(context, project),
      ),
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
        const SizedBox(height: 26),
        const EyebrowRow(label: 'DETAILS'),
        const SizedBox(height: 12),
        GroupedCard(
          children: [
            MondayRow(
              leading: IconTile(
                Icons.folder_outlined,
                background: project.tint.background(p),
              ),
              title: const Text('Colour'),
              subtitle: Text(project.tint.label),
              trailing: const RowChevron(),
              onTap: () => _pickTint(context, store, project),
            ),
          ],
        ),
        const SizedBox(height: 26),
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
                      builder: (_) => TaskDetailScreen(taskId: task.id),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await confirmDeleteProject(context, project)) {
                navigator.pop();
              }
            },
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

  Future<void> _pickTint(
    BuildContext context,
    AppStore store,
    Project project,
  ) async {
    final picked = await showMondayOptionSheet<TileTint>(
      context: context,
      title: 'Colour',
      selected: project.tint,
      options: [
        for (final value in TileTint.values) (value: value, label: value.label),
      ],
    );
    if (picked != null) store.updateProject(project, tint: picked);
  }
}
