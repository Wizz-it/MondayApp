import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';
import '../widgets/creation_sheets.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/grouped_card.dart';
import '../widgets/icon_tile.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/monday_screen.dart';
import '../widgets/screen_header.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.palette;
    final projects = store.projects;

    return MondayScreen(
      showBack: true,
      fab: MondayFab(onPressed: () => showNewProjectSheet(context)),
      children: [
        const ScreenHeader(
          eyebrow: 'YOUR WORKSPACE',
          title: 'Projects',
          subtitle: 'Give your bigger ideas a place to grow.',
        ),
        const SizedBox(height: 30),
        EyebrowRow(
          label: 'ALL PROJECTS',
          trailing: counterLabel(projects.length),
        ),
        const SizedBox(height: 12),
        if (projects.isEmpty)
          EmptyStateCard(
            icon: Icons.folder_outlined,
            title: 'No projects yet',
            message: 'Group related work together to keep it in view.',
            actionLabel: 'Add a project',
            onAction: () => showNewProjectSheet(context),
          )
        else
          Column(
            children: [
              for (final project in projects) ...[
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: MondayRow(
                    leading: IconTile(
                      Icons.folder_outlined,
                      background: project.tint.background(p),
                    ),
                    title: Text(project.name),
                    subtitle: project.description.isEmpty
                        ? null
                        : Text(project.description),
                    trailing: const RowArrow(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProjectDetailScreen(project: project),
                      ),
                    ),
                  ),
                ),
                if (project != projects.last) const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }
}
