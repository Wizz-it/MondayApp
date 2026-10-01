import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/grouped_card.dart';
import '../widgets/icon_tile.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_logo.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;

    return MondayScreen(
      showBack: true,
      children: [
        const ScreenHeader(
          eyebrow: 'PERSONALIZE',
          title: 'Settings',
          subtitle: 'A few things to make this space yours.',
        ),
        const SizedBox(height: 28),
        GroupedCard(
          children: [
            MondayRow(
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: p.tileSage,
                  borderRadius: BorderRadius.circular(MondayRadius.tile),
                ),
                alignment: Alignment.center,
                child: MondayMark(size: 20, color: p.onTile),
              ),
              title: const Text('MONDAY'),
              subtitle: const Text('Your personal productivity assistant'),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const EyebrowRow(label: 'PREFERENCES'),
        const SizedBox(height: 12),
        GroupedCard(
          children: [
            MondayRow(
              leading: IconTile(
                Icons.notifications_none,
                background: p.tileSage,
              ),
              title: const Text('Notifications'),
              subtitle: const Text('Helpful reminders, when you need them'),
              trailing: Switch(
                value: store.notificationsEnabled,
                onChanged: store.setNotificationsEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: p.green,
              ),
            ),
            MondayRow(
              leading: IconTile(
                Icons.palette_outlined,
                background: p.tileSage,
              ),
              title: const Text('Appearance'),
              subtitle: Text(store.isDarkMode ? 'Dark mode' : 'Light mode'),
              trailing: MondayCircleButton(
                icon: store.isDarkMode
                    ? Icons.nightlight_round
                    : Icons.light_mode_outlined,
                onPressed: store.toggleThemeMode,
                background: p.surfaceMuted,
                foreground: p.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const EyebrowRow(label: 'ABOUT'),
        const SizedBox(height: 12),
        GroupedCard(
          children: [
            MondayRow(
              leading: IconTile(
                Icons.info_outline,
                background: p.tileSage,
              ),
              title: const Text('About MONDAY'),
              subtitle: const Text('A little more space for what matters.'),
              trailing: Text(
                'v1.0',
                style: MondayType.rowMeta.copyWith(color: p.inkFaint),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
