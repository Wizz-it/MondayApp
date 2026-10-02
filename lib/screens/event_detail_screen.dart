import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';

/// Event detail, built the same way as the task detail screen: addressed by id
/// so it re-reads the store on every build and notices a deletion.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  TextEditingController? _description;

  @override
  void dispose() {
    _description?.dispose();
    super.dispose();
  }

  /// Keeps the inline description field in sync when the event is edited from
  /// the sheet, without fighting the user while they are typing into it.
  TextEditingController _descriptionFor(CalendarEvent event) {
    final controller = _description ??= TextEditingController();
    if (controller.text != event.description) {
      controller.value = TextEditingValue(
        text: event.description,
        selection: TextSelection.collapsed(offset: event.description.length),
      );
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final event = store.eventById(widget.eventId);

    if (event == null) {
      return const MondayScreen(
        showBack: true,
        children: [
          ScreenHeader(
            eyebrow: 'YOUR EVENT',
            title: 'Event removed',
            subtitle: 'This event is no longer on your calendar.',
          ),
        ],
      );
    }

    return MondayScreen(
      showBack: true,
      headerAction: MondayCircleButton(
        icon: Icons.edit_outlined,
        size: 42,
        background: p.surface,
        foreground: p.ink,
        onPressed: () => showEditEventSheet(context, event),
      ),
      children: [
        ScreenHeader(
          eyebrow: 'YOUR EVENT',
          title: event.title,
          titleStyle: MondayType.displaySoft,
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
              title: const Text('Date'),
              subtitle: Text(relativeDayLabel(event.start)),
              trailing: const RowChevron(),
              onTap: () => _pickDate(store, event),
            ),
            MondayRow(
              leading: Icon(Icons.schedule, size: 19, color: p.inkMuted),
              title: const Text('Time'),
              subtitle: Text(timeLabel(event.start)),
              trailing: const RowChevron(),
              onTap: () => _pickTime(store, event),
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
              controller: _descriptionFor(event),
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
                  store.updateEvent(event, description: value),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _confirmDelete(store, event),
            icon: Icon(Icons.delete_outline, size: 18, color: p.danger),
            label: Text(
              'Delete event',
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

  Future<void> _confirmDelete(AppStore store, CalendarEvent event) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${event.title}" will be removed from your calendar.'),
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
      store.deleteEvent(event);
      navigator.pop();
    }
  }

  /// Moves the event to another day, keeping its time.
  Future<void> _pickDate(AppStore store, CalendarEvent event) async {
    final start = event.start;
    final picked = await showDatePicker(
      context: context,
      initialDate: dayOf(start),
      firstDate: DateTime(start.year - 2),
      lastDate: DateTime(start.year + 5),
    );
    if (picked == null) return;
    store.updateEvent(
      event,
      start: DateTime(
        picked.year,
        picked.month,
        picked.day,
        start.hour,
        start.minute,
      ),
    );
  }

  /// Changes the event's time, keeping its day.
  Future<void> _pickTime(AppStore store, CalendarEvent event) async {
    final start = event.start;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (picked == null) return;
    store.updateEvent(
      event,
      start: DateTime(
        start.year,
        start.month,
        start.day,
        picked.hour,
        picked.minute,
      ),
    );
  }
}
