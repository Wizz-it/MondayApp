import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import 'monday_buttons.dart';

/// Month view with a header, weekday rail and a day grid. The selected day is
/// a filled green square; days carrying a task or event get an activity dot.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.activeDays,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  /// Any date within the month being displayed.
  final DateTime month;
  final DateTime selectedDay;

  /// Day-of-month numbers that have at least one task or event.
  final Set<int> activeDays;

  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  static const _weekdayInitials = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is 1=Mon…7=Sun; the grid starts on Sunday.
    final leadingBlanks = first.weekday % 7;
    final cells = leadingBlanks + daysInMonth;
    final rows = (cells / 7).ceil();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(MondayRadius.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthYear(month),
                  style: MondayType.rowTitle.copyWith(
                    color: p.ink,
                    fontSize: 16.5,
                  ),
                ),
              ),
              MondayCircleButton(
                icon: Icons.chevron_left,
                size: 32,
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month - 1, 1)),
              ),
              const SizedBox(width: 8),
              MondayCircleButton(
                icon: Icons.chevron_right,
                size: 32,
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month + 1, 1)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final d in _weekdayInitials)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: MondayType.rowMeta.copyWith(
                        color: p.inkFaint,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _buildCell(
                      context,
                      row * 7 + col - leadingBlanks + 1,
                      daysInMonth,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCell(BuildContext context, int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: 44);
    }

    final p = context.palette;
    final date = DateTime(month.year, month.month, day);
    final selected = isSameDay(date, selectedDay);
    final hasActivity = activeDays.contains(day);

    return SizedBox(
      height: 44,
      child: Center(
        child: InkWell(
          onTap: () => onDaySelected(date),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? p.green : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: MondayType.rowMeta.copyWith(
                    fontSize: 13.5,
                    height: 1,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? p.onGreen : p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasActivity
                        ? (selected ? p.accent : p.titleAccent)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
