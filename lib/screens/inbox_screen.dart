import 'package:flutter/material.dart';

import '../models/inbox_item.dart';
import '../services/app_store.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';

/// Asks before deleting [item]. Returns whether the item was deleted.
Future<bool> confirmDeleteInboxItem(
  BuildContext context,
  InboxItem item,
) async {
  final store = AppScope.read(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this thought?'),
      content: Text('"${item.text}" will be removed from your inbox.'),
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
  store.deleteInboxItem(item);
  return true;
}

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final items = store.inboxNewestFirst;

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
                    onPressed: () => confirmDeleteInboxItem(context, item),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
