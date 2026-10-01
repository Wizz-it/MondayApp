import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import 'grouped_card.dart';

/// The rounded square checkbox from the reference: an outlined box that fills
/// with the lime accent and shows a check once the task is done.
class MondayCheckbox extends StatelessWidget {
  const MondayCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 24,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      checked: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Keeps the tap target comfortable without enlarging the visual box.
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: value ? p.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: value ? p.accent : p.hairline,
                width: 1.6,
              ),
            ),
            child: value
                ? Icon(Icons.check_rounded, size: size - 8, color: p.onAccent)
                : null,
          ),
        ),
      ),
    );
  }
}

/// A task as it appears in every list: checkbox, title, "Project • Date"
/// metadata and a chevron. Completed tasks are struck through.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.projectName,
    this.onToggle,
    this.onTap,
  });

  final Task task;
  final String? projectName;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final meta = <String>[
      ?projectName,
      if (task.dueDate != null) relativeDayLabel(task.dueDate!),
    ].join('   •   ');

    return MondayRow(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      leading: MondayCheckbox(
        value: task.isDone,
        onChanged: onToggle == null ? null : (_) => onToggle!(),
      ),
      title: Text(
        task.title,
        style: MondayType.rowTitle.copyWith(
          color: task.isDone ? p.inkMuted : p.ink,
          decoration: task.isDone ? TextDecoration.lineThrough : null,
          decorationColor: p.inkMuted,
        ),
      ),
      subtitle: meta.isEmpty
          ? null
          : Text(
              meta,
              style: MondayType.rowMeta.copyWith(color: p.inkMuted),
            ),
      trailing: const RowChevron(),
    );
  }
}
