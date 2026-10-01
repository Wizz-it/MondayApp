import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/monday_sheet.dart';
import '../widgets/screen_header.dart';

/// Full-page task creation.
///
/// The reference creates tasks through the New task bottom sheet, which is what
/// every entry point in the app now uses. This screen is kept as a full-page
/// equivalent of the same form and is not currently routed to.
class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key, this.projectId});

  final String? projectId;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  late DateTime _date = dayOf(DateTime.now());
  late final _dateCtrl = TextEditingController(text: slashDate(_date));

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    AppScope.read(context).addTask(
      title: _name.text.trim(),
      description: _description.text.trim(),
      dueDate: _date,
      projectId: widget.projectId,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return MondayScreen(
      showBack: true,
      children: [
        const ScreenHeader(
          eyebrow: 'MAKE IT HAPPEN',
          title: 'New task',
          subtitle: 'Give it a name and a day to land on.',
        ),
        const SizedBox(height: 30),
        MondayField(
          label: 'Name',
          child: MondayTextField(
            controller: _name,
            autofocus: true,
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
            suffixIcon: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: p.inkMuted,
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(_date.year - 2),
                lastDate: DateTime(_date.year + 5),
              );
              if (picked == null) return;
              setState(() {
                _date = picked;
                _dateCtrl.text = slashDate(picked);
              });
            },
          ),
        ),
        const SizedBox(height: 32),
        MondayPrimaryButton(
          label: 'Create task',
          onPressed: _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
