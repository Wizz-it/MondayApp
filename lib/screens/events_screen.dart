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
import '../widgets/screen_header.dart';

/// A flat list of everything upcoming.
///
/// Calendar is the primary surface for events; this screen is kept outside the
/// main navigation as an alternative list view.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final events = store.upcomingEvents;

    return MondayScreen(
      showBack: true,
      fab: MondayFab(onPressed: () => showNewEventSheet(context)),
      children: [
        const ScreenHeader(
          eyebrow: 'MONDAY  /  EVENTS',
          title: 'Events',
          subtitle: 'Everything coming up, in order.',
        ),
        const SizedBox(height: 30),
        EyebrowRow(
          label: 'UPCOMING',
          trailing: counterLabel(events.length),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          EmptyStateCard(
            icon: Icons.event_outlined,
            title: 'Nothing on the horizon',
            message: 'Events you schedule will line up here.',
            actionLabel: 'Add an event',
            onAction: () => showNewEventSheet(context),
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
                  subtitle: Text(
                    '${relativeDayLabel(event.start)} · '
                    '${timeLabel(event.start)}',
                  ),
                  trailing: MondayCircleButton(
                    icon: Icons.close,
                    size: 30,
                    background: Colors.transparent,
                    foreground: p.inkFaint,
                    onPressed: () => store.deleteEvent(event),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
