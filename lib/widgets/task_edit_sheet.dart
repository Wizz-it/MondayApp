import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/app_store.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import 'monday_sheet.dart';

/// Edits an existing task.
///
/// Shares the creation sheets' chrome so there is only one form style in the
/// app; it just opens pre-filled and saves back to the task it was given.
Future<void> showEditTaskSheet(BuildContext context, Task task) {
  return showMondaySheet<void>(
    context: context,
    builder: (_) => _EditTaskSheet(task: task),
  );
}

class _EditTaskSheet extends StatefulWidget {
  const _EditTaskSheet({required this.task});

  final Task task;

  @override
  State<_EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<_EditTaskSheet> {
  late final _name = TextEditingController(text: widget.task.title);
  late final _description =
      TextEditingController(text: widget.task.description);
  late final _dateCtrl = TextEditingController(text: _dateLabel);

  late DateTime? _date = widget.task.dueDate;
  late TaskPriority _priority = widget.task.priority;
  late String? _projectId = widget.task.projectId;

  String get _dateLabel => _date == null ? 'No due date' : slashDate(_date!);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _setDate(DateTime? value) {
    setState(() {
      _date = value;
      _dateCtrl.text = _dateLabel;
    });
  }

  void _submit() {
    AppScope.read(context).updateTask(
      widget.task,
      title: _name.text.trim(),
      description: _description.text.trim(),
      dueDate: _date,
      clearDueDate: _date == null,
      priority: _priority,
      projectId: _projectId,
      clearProject: _projectId == null,
    );
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final initial = _date ?? dayOf(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 5),
    );
    if (picked != null) _setDate(picked);
  }

  Future<void> _pickPriority() async {
    final picked = await showMondayOptionSheet<TaskPriority>(
      context: context,
      title: 'Priority',
      selected: _priority,
      options: [
        for (final value in TaskPriority.values)
          (value: value, label: value.label),
      ],
    );
    if (picked != null) setState(() => _priority = picked);
  }

  Future<void> _pickProject() async {
    final projects = AppScope.read(context).projects;
    final picked = await showMondayOptionSheet<String>(
      context: context,
      title: 'Project',
      selected: _projectId ?? _noProject,
      options: [
        (value: _noProject, label: 'No project'),
        for (final project in projects)
          (value: project.id, label: project.name),
      ],
    );
    if (picked == null) return;
    setState(() => _projectId = picked == _noProject ? null : picked);
  }

  /// Sentinel for the "unassigned" row, since the option sheet is typed on
  /// non-nullable values.
  static const _noProject = '__none__';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final projectName = store.projectById(_projectId)?.name;

    return MondaySheet(
      eyebrow: 'MAKE IT YOURS',
      title: 'Edit task',
      actionLabel: 'Save changes',
      onAction: _name.text.trim().isEmpty ? null : _submit,
      children: [
        MondayField(
          label: 'Name',
          child: MondayTextField(
            controller: _name,
            hintText: 'What needs to get done?',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 20),
        MondayField(
          label: 'Description',
          optional: true,
          child: MondayTextField(
            controller: _description,
            maxLines: 4,
            hintText: 'Add a little more detail...',
          ),
        ),
        const SizedBox(height: 20),
        MondayField(
          label: 'Date',
          child: MondayTextField(
            controller: _dateCtrl,
            readOnly: true,
            suffixIcon: _date == null
                ? Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: p.inkMuted,
                  )
                : IconButton(
                    icon: Icon(Icons.close, size: 17, color: p.inkMuted),
                    tooltip: 'Clear due date',
                    onPressed: () => _setDate(null),
                  ),
            onTap: _pickDate,
          ),
        ),
        const SizedBox(height: 20),
        MondayField(
          label: 'Priority',
          child: MondaySelectField(
            value: _priority.label,
            onTap: _pickPriority,
          ),
        ),
        const SizedBox(height: 20),
        MondayField(
          label: 'Project',
          optional: true,
          child: MondaySelectField(
            value: projectName ?? 'No project',
            placeholder: projectName == null,
            onTap: _pickProject,
          ),
        ),
      ],
    );
  }
}
