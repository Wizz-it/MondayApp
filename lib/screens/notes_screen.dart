import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../utils/date_labels.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/note_card.dart';
import '../widgets/screen_header.dart';
import 'note_detail_screen.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final notes = store.notes;

    return MondayScreen(
      showBack: true,
      fab: MondayFab(onPressed: () => showNewNoteSheet(context)),
      children: [
        const ScreenHeader(
          eyebrow: 'THOUGHTS & IDEAS',
          title: 'Notes',
          subtitle: 'A quiet place to keep the things worth remembering.',
        ),
        const SizedBox(height: 30),
        EyebrowRow(
          label: 'ALL NOTES',
          trailing: counterLabel(notes.length),
        ),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          EmptyStateCard(
            icon: Icons.description_outlined,
            title: 'Nothing written down yet',
            message: 'Keep the thoughts you want to come back to.',
            actionLabel: 'Add a note',
            onAction: () => showNewNoteSheet(context),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.84,
            ),
            itemBuilder: (context, i) => NoteCard(
              note: notes[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NoteDetailScreen(note: notes[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
