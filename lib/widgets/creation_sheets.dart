import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../services/app_store.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import 'monday_sheet.dart';

/// The five creation flows from the reference. Each is a bottom sheet sharing
/// the [MondaySheet] chrome; each writes straight to the [AppStore]. The event
/// sheet doubles as the edit form for an existing event.

Future<void> showNewTaskSheet(BuildContext context, {String? projectId}) {
  return showMondaySheet<void>(
    context: context,
    builder: (_) => _NewTaskSheet(projectId: projectId),
  );
}

/// Completes with the created event, or null if the sheet was dismissed.
Future<CalendarEvent?> showNewEventSheet(
  BuildContext context, {
  DateTime? initialDay,
}) {
  return showMondaySheet<CalendarEvent>(
    context: context,
    builder: (_) => _EventSheet(initialDay: initialDay),
  );
}

/// The new-event sheet, opened pre-filled. Completes with the event once it
/// has been saved, or null if the sheet was dismissed.
Future<CalendarEvent?> showEditEventSheet(
  BuildContext context,
  CalendarEvent event,
) {
  return showMondaySheet<CalendarEvent>(
    context: context,
    builder: (_) => _EventSheet(event: event),
  );
}

Future<void> showNewProjectSheet(BuildContext context) {
  return showMondaySheet<void>(
    context: context,
    builder: (_) => const _NewProjectSheet(),
  );
}

Future<void> showNewNoteSheet(BuildContext context) {
  return showMondaySheet<void>(
    context: context,
    builder: (_) => const _NewNoteSheet(),
  );
}

Future<void> showCaptureThoughtSheet(BuildContext context) {
  return showMondaySheet<void>(
    context: context,
    builder: (_) => const _CaptureThoughtSheet(),
  );
}

/// Shared date picker so every sheet opens the same themed dialog.
Future<DateTime?> _pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(initial.year - 2),
    lastDate: DateTime(initial.year + 5),
  );
}

// New task -------------------------------------------------------------------

class _NewTaskSheet extends StatefulWidget {
  const _NewTaskSheet({this.projectId});

  final String? projectId;

  @override
  State<_NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends State<_NewTaskSheet> {
  final _name = TextEditingController();
  late DateTime _date = dayOf(DateTime.now());
  late final _dateCtrl = TextEditingController(text: slashDate(_date));

  @override
  void dispose() {
    _name.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _setDate(DateTime value) {
    setState(() {
      _date = value;
      _dateCtrl.text = slashDate(value);
    });
  }

  void _submit() {
    AppScope.read(context).addTask(
      title: _name.text.trim(),
      dueDate: _date,
      projectId: widget.projectId,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return MondaySheet(
      title: 'New task',
      actionLabel: 'Create task',
      onAction: _name.text.trim().isEmpty ? null : _submit,
      children: [
        MondayField(
          label: 'Name',
          child: MondayTextField(
            controller: _name,
            autofocus: true,
            hintText: 'What needs to get done?',
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_name.text.trim().isNotEmpty) _submit();
            },
          ),
        ),
        const SizedBox(height: 20),
        MondayField(
          label: 'Date',
          child: MondayTextField(
            controller: _dateCtrl,
            readOnly: true,
            suffixIcon: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: context.palette.inkMuted,
            ),
            onTap: () async {
              final picked = await _pickDate(context, _date);
              if (picked != null) _setDate(picked);
            },
          ),
        ),
      ],
    );
  }
}

// New / edit event -----------------------------------------------------------

class _EventSheet extends StatefulWidget {
  const _EventSheet({this.initialDay, this.event});

  final DateTime? initialDay;

  /// The event being edited, or null when creating one.
  final CalendarEvent? event;

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  late final _name = TextEditingController(text: widget.event?.title);
  late final _description =
      TextEditingController(text: widget.event?.description);
  late DateTime _date =
      dayOf(widget.event?.start ?? widget.initialDay ?? DateTime.now());
  late TimeOfDay _time = widget.event == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(widget.event!.start);
  late final _dateCtrl = TextEditingController(text: slashDate(_date));
  late final _timeCtrl = TextEditingController(text: _formattedTime);

  bool get _isEditing => widget.event != null;

  DateTime get _start =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  String get _formattedTime => dottedTime(_start);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final store = AppScope.read(context);
    final existing = widget.event;
    final CalendarEvent saved;
    if (existing == null) {
      saved = store.addEvent(
        title: _name.text.trim(),
        start: _start,
        description: _description.text.trim(),
      );
    } else {
      store.updateEvent(
        existing,
        title: _name.text.trim(),
        start: _start,
        description: _description.text.trim(),
      );
      saved = existing;
    }
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return MondaySheet(
      eyebrow: _isEditing ? 'MAKE IT YOURS' : 'MAKE IT HAPPEN',
      title: _isEditing ? 'Edit event' : 'New event',
      actionLabel: _isEditing ? 'Save changes' : 'Create event',
      onAction: _name.text.trim().isEmpty ? null : _submit,
      children: [
        MondayField(
          label: 'Name',
          child: MondayTextField(
            controller: _name,
            autofocus: !_isEditing,
            hintText: "What's happening?",
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MondayField(
                label: 'Date',
                child: MondayTextField(
                  controller: _dateCtrl,
                  readOnly: true,
                  suffixIcon: Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: p.inkMuted,
                  ),
                  onTap: () async {
                    final picked = await _pickDate(context, _date);
                    if (picked == null) return;
                    setState(() {
                      _date = picked;
                      _dateCtrl.text = slashDate(picked);
                      _timeCtrl.text = _formattedTime;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: MondayField(
                label: 'Time',
                child: MondayTextField(
                  controller: _timeCtrl,
                  readOnly: true,
                  suffixIcon: Icon(
                    Icons.schedule,
                    size: 17,
                    color: p.inkMuted,
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (picked == null) return;
                    setState(() {
                      _time = picked;
                      _timeCtrl.text = _formattedTime;
                    });
                  },
                ),
              ),
            ),
          ],
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
      ],
    );
  }
}

// New project ----------------------------------------------------------------

class _NewProjectSheet extends StatefulWidget {
  const _NewProjectSheet();

  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    AppScope.read(context).addProject(
      name: _name.text.trim(),
      description: _description.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return MondaySheet(
      title: 'New project',
      actionLabel: 'Create project',
      onAction: _name.text.trim().isEmpty ? null : _submit,
      children: [
        MondayField(
          label: 'Name',
          child: MondayTextField(
            controller: _name,
            autofocus: true,
            hintText: 'Name your project',
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
      ],
    );
  }
}

// New note -------------------------------------------------------------------

class _NewNoteSheet extends StatefulWidget {
  const _NewNoteSheet();

  @override
  State<_NewNoteSheet> createState() => _NewNoteSheetState();
}

class _NewNoteSheetState extends State<_NewNoteSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _submit() {
    AppScope.read(context).addNote(
      title: _title.text.trim(),
      body: _body.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return MondaySheet(
      title: 'New note',
      actionLabel: 'Create note',
      onAction: _title.text.trim().isEmpty ? null : _submit,
      children: [
        MondayField(
          label: 'Title',
          child: MondayTextField(
            controller: _title,
            autofocus: true,
            hintText: 'Name your note',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 20),
        MondayField(
          label: 'Your note',
          optional: true,
          child: MondayTextField(
            controller: _body,
            maxLines: 4,
            hintText: 'Add a little more detail...',
          ),
        ),
      ],
    );
  }
}

// Capture a thought ----------------------------------------------------------

class _CaptureThoughtSheet extends StatefulWidget {
  const _CaptureThoughtSheet();

  @override
  State<_CaptureThoughtSheet> createState() => _CaptureThoughtSheetState();
}

class _CaptureThoughtSheetState extends State<_CaptureThoughtSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    AppScope.read(context).captureThought(_text.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return MondaySheet(
      title: 'Capture a thought',
      actionLabel: 'Save to inbox',
      onAction: _text.text.trim().isEmpty ? null : _submit,
      children: [
        MondayField(
          label: "What's on your mind?",
          child: MondayTextField(
            controller: _text,
            autofocus: true,
            hintText: 'Capture anything...',
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_text.text.trim().isNotEmpty) _submit();
            },
          ),
        ),
      ],
    );
  }
}
