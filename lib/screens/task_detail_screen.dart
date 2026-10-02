import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/monday_sheet.dart';
import '../widgets/screen_header.dart';
import '../widgets/task_edit_sheet.dart';
import '../widgets/task_row.dart';

/// Task detail.
///
/// The PDF does not include this screen, so the layout is extrapolated from the
/// fields the previous implementation carried (status, description, due date,
/// reminder, priority) dressed in the reference's visual language.
///
/// The screen is addressed by task id rather than by object: the store is the
/// single source of truth, so every build re-reads the task and the screen can
/// close itself if the task has been deleted.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TextEditingController? _description;

  @override
  void dispose() {
    _description?.dispose();
    super.dispose();
  }

  /// Keeps the inline description field in sync when the task is edited from
  /// the sheet, without fighting the user while they are typing into it.
  TextEditingController _descriptionFor(Task task) {
    final controller = _description ??= TextEditingController();
    if (controller.text != task.description) {
      controller.value = TextEditingValue(
        text: task.description,
        selection: TextSelection.collapsed(offset: task.description.length),
      );
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final task = store.taskById(widget.taskId);

    // The task was deleted from somewhere else while this screen was open.
    if (task == null) {
      return const MondayScreen(
        showBack: true,
        children: [
          ScreenHeader(
            eyebrow: 'YOUR TASK',
            title: 'Task removed',
            subtitle: 'This task is no longer in your list.',
          ),
        ],
      );
    }

    final project = store.projectById(task.projectId);

    return MondayScreen(
      showBack: true,
      headerAction: MondayCircleButton(
        icon: Icons.edit_outlined,
        size: 42,
        background: p.surface,
        foreground: p.ink,
        onPressed: () => showEditTaskSheet(context, task),
      ),
      children: [
        ScreenHeader(
          eyebrow: 'YOUR TASK',
          title: task.title,
          titleStyle: MondayType.displaySoft,
        ),
        const SizedBox(height: 26),
        GroupedCard(
          children: [
            MondayRow(
              padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
              leading: MondayCheckbox(
                value: task.isDone,
                onChanged: (_) => store.toggleTask(task),
              ),
              title: Text(task.isDone ? 'Completed' : 'Mark as done'),
              subtitle: Text(
                task.isDone
                    ? 'Nice work. Tap to reopen it.'
                    : 'Still on your plate.',
              ),
              onTap: () => store.toggleTask(task),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const EyebrowRow(label: 'DETAILS'),
        const SizedBox(height: 12),
        GroupedCard(
          children: [
            MondayRow(
              leading: Icon(
                Icons.calendar_today_outlined,
                size: 19,
                color: p.inkMuted,
              ),
              title: const Text('Due date'),
              subtitle: Text(
                task.dueDate == null
                    ? 'Not set'
                    : relativeDayLabel(task.dueDate!),
              ),
              trailing: _ClearableChevron(
                onClear: task.dueDate == null
                    ? null
                    : () => store.updateTask(task, clearDueDate: true),
              ),
              onTap: () => _pickDueDate(store, task),
            ),
            MondayRow(
              leading: Icon(
                Icons.notifications_none,
                size: 19,
                color: p.inkMuted,
              ),
              title: const Text('Reminder'),
              subtitle: Text(
                task.reminder == null
                    ? 'Not set'
                    : '${relativeDayLabel(task.reminder!)} · '
                        '${timeLabel(task.reminder!)}',
              ),
              trailing: _ClearableChevron(
                onClear: task.reminder == null
                    ? null
                    : () => store.updateTask(task, clearReminder: true),
              ),
              onTap: () => _pickReminder(store, task),
            ),
            MondayRow(
              leading: Icon(Icons.flag_outlined, size: 19, color: p.inkMuted),
              title: const Text('Priority'),
              subtitle: Text(task.priority.label),
              trailing: const RowChevron(),
              onTap: () => _pickPriority(store, task),
            ),
            MondayRow(
              leading: Icon(Icons.folder_outlined, size: 19, color: p.inkMuted),
              title: const Text('Project'),
              subtitle: Text(project?.name ?? 'No project'),
              trailing: const RowChevron(),
              onTap: () => _pickProject(store, task),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const EyebrowRow(label: 'DESCRIPTION'),
        const SizedBox(height: 12),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 110),
            child: TextField(
              controller: _descriptionFor(task),
              maxLines: null,
              style: MondayType.body.copyWith(color: p.ink),
              cursorColor: p.green,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Add some details...',
                hintStyle: MondayType.body.copyWith(color: p.inkFaint),
              ),
              onChanged: (value) =>
                  store.updateTask(task, description: value),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _confirmDelete(store, task),
            icon: Icon(Icons.delete_outline, size: 18, color: p.danger),
            label: Text(
              'Delete task',
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

  Future<void> _confirmDelete(AppStore store, Task task) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed from your list.'),
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
      store.deleteTask(task);
      navigator.pop();
    }
  }

  Future<void> _pickDueDate(AppStore store, Task task) async {
    final initial = task.dueDate ?? dayOf(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 5),
    );
    if (picked != null) store.updateTask(task, dueDate: picked);
  }

  /// Reminders are stored as a date and time on the task. Nothing schedules
  /// them yet — notifications are a later piece of work.
  Future<void> _pickReminder(AppStore store, Task task) async {
    final base = task.reminder ?? task.dueDate ?? DateTime.now();

    final day = await showDatePicker(
      context: context,
      initialDate: dayOf(base),
      firstDate: DateTime(base.year - 2),
      lastDate: DateTime(base.year + 5),
    );
    if (day == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;

    store.updateTask(
      task,
      reminder: DateTime(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  Future<void> _pickPriority(AppStore store, Task task) async {
    final picked = await showMondayOptionSheet<TaskPriority>(
      context: context,
      title: 'Priority',
      selected: task.priority,
      options: [
        for (final value in TaskPriority.values)
          (value: value, label: value.label),
      ],
    );
    if (picked != null) store.updateTask(task, priority: picked);
  }

  Future<void> _pickProject(AppStore store, Task task) async {
    const noProject = '__none__';
    final picked = await showMondayOptionSheet<String>(
      context: context,
      title: 'Project',
      selected: task.projectId ?? noProject,
      options: [
        (value: noProject, label: 'No project'),
        for (final project in store.projects)
          (value: project.id, label: project.name),
      ],
    );
    if (picked == null) return;
    if (picked == noProject) {
      store.updateTask(task, clearProject: true);
    } else {
      store.updateTask(task, projectId: picked);
    }
  }
}

/// Row trailing widget that becomes a clear button once the field has a value.
class _ClearableChevron extends StatelessWidget {
  const _ClearableChevron({this.onClear});

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    if (onClear == null) return const RowChevron();
    return MondayCircleButton(
      icon: Icons.close,
      size: 30,
      background: Colors.transparent,
      foreground: context.palette.inkFaint,
      onPressed: onClear!,
    );
  }
}
