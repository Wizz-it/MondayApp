import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';
import '../widgets/task_row.dart';

/// Task detail.
///
/// The PDF does not include this screen, so the layout is extrapolated from the
/// fields the previous implementation carried (status, description, due date,
/// reminder, priority) dressed in the reference's visual language.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.task});

  final Task task;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TextEditingController _description =
      TextEditingController(text: widget.task.description);

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final task = widget.task;
    final project = store.projectById(task.projectId);

    return MondayScreen(
      showBack: true,
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
              trailing: const RowChevron(),
              onTap: () => _pickDueDate(store),
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
              trailing: const RowChevron(),
              onTap: () => _pickReminder(store),
            ),
            MondayRow(
              leading: Icon(Icons.flag_outlined, size: 19, color: p.inkMuted),
              title: const Text('Priority'),
              subtitle: Text(task.priority.label),
              trailing: const RowChevron(),
              onTap: () => _pickPriority(store),
            ),
            MondayRow(
              leading: Icon(Icons.folder_outlined, size: 19, color: p.inkMuted),
              title: const Text('Project'),
              subtitle: Text(project?.name ?? 'No project'),
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
              controller: _description,
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
            onPressed: () {
              store.deleteTask(task);
              Navigator.of(context).pop();
            },
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

  Future<void> _pickDueDate(AppStore store) async {
    final initial = widget.task.dueDate ?? dayOf(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 5),
    );
    if (picked != null) store.updateTask(widget.task, dueDate: picked);
  }

  Future<void> _pickReminder(AppStore store) async {
    final base = widget.task.reminder ?? widget.task.dueDate ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final day = widget.task.dueDate ?? dayOf(DateTime.now());
    store.updateTask(
      widget.task,
      reminder: DateTime(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  Future<void> _pickPriority(AppStore store) async {
    final p = context.palette;
    final picked = await showModalBottomSheet<TaskPriority>(
      context: context,
      backgroundColor: p.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in TaskPriority.values)
              ListTile(
                title: Text(
                  value.label,
                  style: MondayType.rowTitle.copyWith(color: p.ink),
                ),
                trailing: value == widget.task.priority
                    ? Icon(Icons.check, size: 19, color: p.green)
                    : null,
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    );
    if (picked != null) store.updateTask(widget.task, priority: picked);
  }
}
