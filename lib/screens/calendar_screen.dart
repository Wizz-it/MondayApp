import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/grouped_card.dart';
import '../widgets/icon_tile.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/month_grid.dart';
import '../widgets/screen_header.dart';
import 'task_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDay = dayOf(DateTime.now());
  late DateTime _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month);

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;

    final events = store.eventsOn(_selectedDay);
    final tasks = store.tasksOn(_selectedDay);
    final isToday = isSameDay(_selectedDay, DateTime.now());

    return MondayScreen(
      fab: MondayFab(
        onPressed: () => showNewEventSheet(context, initialDay: _selectedDay),
      ),
      children: [
        const ScreenHeader(
          eyebrow: 'MONDAY  /  CALENDAR',
          title: 'Calendar',
          subtitle: "See what's ahead, at a glance.",
        ),
        const SizedBox(height: 24),
        MonthGrid(
          month: _visibleMonth,
          selectedDay: _selectedDay,
          activeDays: store.activeDaysIn(_visibleMonth),
          onDaySelected: (day) => setState(() => _selectedDay = day),
          onMonthChanged: (month) => setState(() => _visibleMonth = month),
        ),
        const SizedBox(height: 28),
        SectionHeader(
          title: isToday
              ? "Today's schedule"
              : 'Schedule for ${relativeDayLabel(_selectedDay)}',
        ),
        const SizedBox(height: 14),
        if (events.isEmpty && tasks.isEmpty)
          EmptyStateCard(
            icon: Icons.event_outlined,
            title: 'Nothing planned',
            message: 'This day is still open. Add an event to fill it in.',
            actionLabel: 'Add an event',
            onAction: () =>
                showNewEventSheet(context, initialDay: _selectedDay),
          )
        else
          GroupedCard(
            children: [
              for (final event in events)
                MondayRow(
                  leading: IconTile(
                    Icons.calendar_today_outlined,
                    background: p.tileSage,
                  ),
                  title: Text(event.title),
                  subtitle: Text('Event · ${timeLabel(event.start)}'),
                ),
              for (final task in tasks)
                MondayRow(
                  leading: IconTile(
                    Icons.check_circle_outline,
                    background: p.tileLilac,
                  ),
                  title: Text(task.title),
                  subtitle: Text(
                    'Task${store.projectNameFor(task) == null ? '' : ' · ${store.projectNameFor(task)}'}',
                  ),
                  trailing: const RowChevron(),
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
}
