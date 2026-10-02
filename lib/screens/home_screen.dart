import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/assistant_hero_card.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/date_tile.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_logo.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';
import '../widgets/task_row.dart';
import 'talk_screen.dart';
import 'task_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Lets the "View tasks" and "Open calendar" links move the shell's tab.
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final now = DateTime.now();

    final todayTasks = store.tasksFor(TaskFilter.today, now: now);
    final todayEvents = store.eventsOn(now);

    return MondayScreen(
      children: [
        Row(
          children: [
            const Expanded(child: MondayWordmark()),
            _Avatar(initial: store.userName.characters.first),
          ],
        ),
        const SizedBox(height: 42),
        EyebrowLabel(fullDateLabel(now), leadingRule: true),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            text: '${greetingFor(now)},\n',
            style: MondayType.displaySoft.copyWith(color: p.ink),
            children: [
              TextSpan(
                text: store.userName,
                style: MondayType.displaySoft.copyWith(color: p.titleAccent),
              ),
              TextSpan(
                text: '.',
                style: MondayType.displaySoft.copyWith(color: p.titleAccent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Here's your space to make today count.",
          style: MondayType.body.copyWith(color: p.inkMuted),
        ),
        const SizedBox(height: 26),
        AssistantHeroCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TalkScreen()),
          ),
        ),
        const SizedBox(height: 30),
        SectionHeader(
          title: "Today's focus",
          actionLabel: 'View tasks',
          onAction: () => onOpenTab(1),
        ),
        const SizedBox(height: 14),
        GroupedCard(
          children: [
            _CardEyebrow(
              label: 'TO DO',
              badge: '${todayTasks.length} '
                  '${todayTasks.length == 1 ? 'task' : 'tasks'}',
            ),
            if (todayTasks.isEmpty)
              const _CardMessage(
                icon: Icons.check_circle_outline,
                text: 'Nothing due today. Enjoy the quiet.',
              )
            else
              for (final task in todayTasks)
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
            _AddRow(
              label: 'Add a task',
              onTap: () => showNewTaskSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 30),
        SectionHeader(
          title: 'On your calendar',
          actionLabel: 'Open calendar',
          onAction: () => onOpenTab(2),
        ),
        const SizedBox(height: 14),
        GroupedCard(
          children: [
            if (todayEvents.isEmpty)
              const _CardMessage(
                icon: Icons.event_outlined,
                text: 'No events today.',
              )
            else
              for (final event in todayEvents)
                MondayRow(
                  leading: DateTile(event.start),
                  title: Text(event.title),
                  subtitle: Text(
                    '${relativeDayLabel(event.start)} · '
                    '${timeLabel(event.start)}',
                  ),
                  trailing: const RowChevron(),
                  onTap: () => onOpenTab(2),
                ),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: p.tileSage, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: MondayType.rowTitle.copyWith(color: p.onTile),
      ),
    );
  }
}

/// The small header strip inside a card: "TO DO" with a count pill.
class _CardEyebrow extends StatelessWidget {
  const _CardEyebrow({required this.label, required this.badge});

  final String label;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          Expanded(child: EyebrowLabel(label)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: p.tileSage,
              borderRadius: BorderRadius.circular(MondayRadius.pill),
            ),
            child: Text(
              badge,
              style: MondayType.rowMeta.copyWith(
                color: p.onTile,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet in-card message for the moments a list is empty.
class _CardMessage extends StatelessWidget {
  const _CardMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Icon(icon, size: 19, color: p.inkFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: MondayType.rowMeta.copyWith(
                color: p.inkMuted,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "+ Add a task" row that closes the Home to-do card.
class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.add, size: 18, color: p.inkMuted),
              const SizedBox(width: 12),
              Text(
                label,
                style: MondayType.rowTitle.copyWith(color: p.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
