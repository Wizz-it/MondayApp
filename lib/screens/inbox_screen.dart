import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final items = store.inbox;

    return MondayScreen(
      showBack: true,
      fab: MondayFab(onPressed: () => showCaptureThoughtSheet(context)),
      children: [
        const ScreenHeader(
          eyebrow: 'CAPTURE SPACE',
          title: 'Inbox',
          subtitle: 'A home for thoughts before they become plans.',
        ),
        const SizedBox(height: 30),
        EyebrowRow(
          label: 'CAPTURED',
          trailing: counterLabel(items.length),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          EmptyStateCard(
            icon: Icons.inbox_outlined,
            title: 'A clear inbox feels good',
            message: 'Capture anything on your mind. You can sort it out later.',
            actionLabel: 'Capture a thought',
            onAction: () => showCaptureThoughtSheet(context),
          )
        else
          GroupedCard(
            children: [
              for (final item in items)
                MondayRow(
                  title: Text(item.text),
                  subtitle: Text(
                    '${relativeDayLabel(item.capturedAt)} · '
                    '${timeLabel(item.capturedAt)}',
                  ),
                  trailing: MondayCircleButton(
                    icon: Icons.close,
                    size: 30,
                    background: Colors.transparent,
                    foreground: p.inkFaint,
                    onPressed: () => store.deleteInboxItem(item),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
