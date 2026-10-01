import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';

/// Note reader and editor. The reference shows the body in a plain white card
/// with a delete affordance underneath; here the card is editable so the note
/// can actually be changed.
class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.note});

  final Note note;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late final TextEditingController _body =
      TextEditingController(text: widget.note.body);

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;

    return MondayScreen(
      showBack: true,
      children: [
        ScreenHeader(
          eyebrow: 'YOUR NOTE',
          title: widget.note.title,
          titleStyle: MondayType.displaySoft,
        ),
        const SizedBox(height: 26),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 160),
            child: TextField(
              controller: _body,
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
              onChanged: (value) =>
                  store.updateNote(widget.note, body: value),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              store.deleteNote(widget.note);
              Navigator.of(context).pop();
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
