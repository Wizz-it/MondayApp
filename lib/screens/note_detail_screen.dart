import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';

/// Asks before deleting [note]. Returns whether the note was deleted.
Future<bool> confirmDeleteNote(BuildContext context, Note note) async {
  final store = AppScope.read(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete note?'),
      content: Text('"${note.title}" will be removed from your notes.'),
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
  if (!(confirmed ?? false)) return false;
  store.deleteNote(note);
  return true;
}

/// Note reader and editor. The reference shows the body in a plain white card
/// with a delete affordance underneath; here the card is editable so the note
/// can actually be changed, and the title is edited from the sheet.
///
/// Addressed by id, like the task, event and project detail screens, so it
/// always shows the store's current version and notices a deletion.
class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  TextEditingController? _body;

  @override
  void dispose() {
    _body?.dispose();
    super.dispose();
  }

  /// Keeps the inline body field in sync when the note is edited from the
  /// sheet, without fighting the user while they are typing into it.
  TextEditingController _bodyFor(Note note) {
    final controller = _body ??= TextEditingController();
    if (controller.text != note.body) {
      controller.value = TextEditingValue(
        text: note.body,
        selection: TextSelection.collapsed(offset: note.body.length),
      );
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final note = store.noteById(widget.noteId);

    if (note == null) {
      return const MondayScreen(
        showBack: true,
        children: [
          ScreenHeader(
            eyebrow: 'YOUR NOTE',
            title: 'Note removed',
            subtitle: 'This note is no longer in your notes.',
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
        onPressed: () => showEditNoteSheet(context, note),
      ),
      children: [
        ScreenHeader(
          eyebrow: 'YOUR NOTE',
          title: note.title,
          titleStyle: MondayType.displaySoft,
        ),
        const SizedBox(height: 26),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 160),
            child: TextField(
              controller: _bodyFor(note),
              maxLines: null,
              style: MondayType.body.copyWith(color: p.ink),
              cursorColor: p.green,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Start writing...',
                hintStyle: MondayType.body.copyWith(color: p.inkFaint),
              ),
              onChanged: (value) => store.updateNote(note, body: value),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await confirmDeleteNote(context, note)) navigator.pop();
            },
            icon: Icon(Icons.delete_outline, size: 18, color: p.danger),
            label: Text(
              'Delete note',
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
}
