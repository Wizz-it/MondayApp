import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/grouped_card.dart';
import '../widgets/icon_tile.dart';
import '../widgets/monday_logo.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';
import 'inbox_screen.dart';
import 'notes_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';
import 'talk_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    void open(Widget screen) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    return MondayScreen(
      children: [
        const ScreenHeader(
          eyebrow: 'MONDAY  /  MORE',
          title: 'More',
          subtitle: 'Everything else, in one place.',
        ),
        const SizedBox(height: 30),
        const EyebrowRow(label: 'YOUR WORKSPACE'),
        const SizedBox(height: 12),
        GroupedCard(
          children: [
            MondayRow(
              leading: IconTile(
                Icons.inbox_outlined,
                background: p.tileSage,
              ),
              title: const Text('Inbox'),
              subtitle: const Text('Capture first, organize later.'),
              trailing: const RowChevron(),
              onTap: () => open(const InboxScreen()),
            ),
            MondayRow(
              leading: IconTile(
                Icons.folder_outlined,
                background: p.tileSage,
              ),
              title: const Text('Projects'),
              subtitle: const Text('Keep your work together.'),
              trailing: const RowChevron(),
              onTap: () => open(const ProjectsScreen()),
            ),
            MondayRow(
              leading: IconTile(
                Icons.description_outlined,
                background: p.tileLilac,
              ),
              title: const Text('Notes'),
              subtitle: const Text('Thoughts worth keeping.'),
              trailing: const RowChevron(),
              onTap: () => open(const NotesScreen()),
            ),
            MondayRow(
              leading: IconTile(
                Icons.mic_none,
                background: p.tileSage,
              ),
              title: const Text('Talk to MONDAY'),
              subtitle: const Text('A thought away from clarity.'),
              trailing: const RowChevron(),
              onTap: () => open(const TalkScreen()),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const EyebrowRow(label: 'PREFERENCES'),
        const SizedBox(height: 12),
        GroupedCard(
          children: [
            MondayRow(
              leading: IconTile(
                Icons.settings_outlined,
                background: p.tileSage,
              ),
              title: const Text('Settings'),
              subtitle: const Text('Make MONDAY yours.'),
              trailing: const RowChevron(),
              onTap: () => open(const SettingsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MondayMark(size: 16, color: p.inkFaint),
            const SizedBox(width: 10),
            Text(
              'Make room for what matters.',
              style: MondayType.rowMeta.copyWith(
                color: p.inkFaint,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
