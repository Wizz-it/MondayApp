import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// A note as it appears in the two-column grid on the Notes screen.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(MondayRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 21, color: p.titleAccent),
              const SizedBox(height: 18),
              Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MondayType.rowTitle.copyWith(color: p.ink, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                note.body.isEmpty ? 'No detail yet.' : note.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MondayType.rowMeta.copyWith(
                  color: p.inkMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'OPEN NOTE',
                      style: MondayType.eyebrow.copyWith(
                        color: p.inkMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 15, color: p.inkMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
