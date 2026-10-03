import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/models/tile_tint.dart';
import 'package:mondayapp/screens/project_detail_screen.dart';
import 'package:mondayapp/screens/projects_screen.dart';
import 'package:mondayapp/services/app_storage.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/theme/app_theme.dart';

Widget hostScreen(AppStore store, Widget child) {
  return AppScope(
    store: store,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        theme: mondayLightTheme,
        home: child,
      ),
    ),
  );
}

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(440, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Saves, then opens a fresh store on the same storage, as a relaunch would.
Future<AppStore> restart(AppStore store, AppStorage storage) async {
  await store.flush();
  store.dispose();
  return AppStore.open(storage);
}

void main() {
  final seed = DateTime(2026, 10, 1, 9);

  group('store project operations', () {
    late AppStore store;

    setUp(() => store = AppStore(seedDate: seed));

    test('addProject creates a project that can be looked up', () {
      final project = store.addProject(name: 'Garden', description: 'Beds');

      expect(store.projectById(project.id), same(project));
      expect(project.name, 'Garden');
      expect(project.description, 'Beds');
      expect(store.projects, hasLength(3));
    });

    test('new projects alternate tints, as before', () {
      // Two seed projects, so the third is sage and the fourth lilac.
      expect(store.addProject(name: 'Third').tint, TileTint.sage);
      expect(store.addProject(name: 'Fourth').tint, TileTint.lilac);
    });

    test('updateProject changes name, description and tint', () {
      final project = store.projects.first;

      store.updateProject(
        project,
        name: 'MONDAY app',
        description: 'Shipping v1',
        tint: TileTint.lilac,
      );

      expect(project.name, 'MONDAY app');
      expect(project.description, 'Shipping v1');
      expect(project.tint, TileTint.lilac);
    });

    test('updateProject leaves fields it was not given alone', () {
      final project = store.projects.first;

      store.updateProject(project, name: 'Renamed');

      expect(project.description, 'Product design and development');
      expect(project.tint, TileTint.sage);
    });

    test('several projects can exist side by side', () {
      final a = store.addProject(name: 'A');
      final b = store.addProject(name: 'B');

      expect(store.projects.map((p) => p.name),
          ['MONDAY', 'Portfolio', 'A', 'B']);
      expect(a.id, isNot(b.id));
    });

    test('a task assigned to a project is listed under it', () {
      final project = store.addProject(name: 'Garden');
      final task = store.addTask(title: 'Plant tulips');

      store.updateTask(task, projectId: project.id);

      expect(store.tasksForProject(project.id), [task]);
      expect(store.projectNameFor(task), 'Garden');
    });

    test('moving a task changes which project lists it', () {
      final from = store.addProject(name: 'From');
      final to = store.addProject(name: 'To');
      final task = store.addTask(title: 'Mover', projectId: from.id);

      store.updateTask(task, projectId: to.id);

      expect(store.tasksForProject(from.id), isEmpty);
      expect(store.tasksForProject(to.id), [task]);
    });

    test('clearing a task\'s project removes it from that project', () {
      final project = store.addProject(name: 'Garden');
      final task = store.addTask(title: 'Weed', projectId: project.id);

      store.updateTask(task, clearProject: true);

      expect(store.tasksForProject(project.id), isEmpty);
      expect(store.taskById(task.id), same(task));
    });

    test('deleting a project keeps its tasks and unassigns them', () {
      final project = store.projects.first;
      final attached = store.tasksForProject(project.id);
      final other = store.tasksForProject(store.projects.last.id);
      final taskCount = store.tasks.length;
      expect(attached, isNotEmpty);

      store.deleteProject(project);

      expect(store.projectById(project.id), isNull);
      expect(store.tasks, hasLength(taskCount));
      for (final task in attached) {
        expect(store.taskById(task.id), same(task));
        expect(task.projectId, isNull);
      }
      // Tasks in other projects are untouched.
      for (final task in other) {
        expect(task.projectId, store.projects.single.id);
      }
    });

    test('project changes notify listeners', () {
      var notified = 0;
      store.addListener(() => notified++);

      final project = store.addProject(name: 'Ping');
      store.updateProject(project, name: 'Pong');
      store.deleteProject(project);

      expect(notified, 3);
    });
  });

  group('project persistence', () {
    late MemoryAppStorage storage;
    late AppStore store;

    setUp(() async {
      storage = MemoryAppStorage();
      store = await AppStore.open(storage, seedDate: seed);
    });

    test('a created and edited project survives a restart', () async {
      final project = store.addProject(name: 'Draft', description: 'First');
      store.updateProject(
        project,
        name: 'Garden',
        description: 'Raised beds',
        tint: TileTint.lilac,
      );

      final restored = (await restart(store, storage)).projectById(project.id)!;

      expect(restored.name, 'Garden');
      expect(restored.description, 'Raised beds');
      expect(restored.tint, TileTint.lilac);
    });

    test('task/project relationships survive a restart', () async {
      final garden = store.addProject(name: 'Garden');
      final moved = store.tasks.first..projectId = garden.id;
      final cleared = store.tasks[1];
      store.updateTask(cleared, clearProject: true);
      store.updateTask(moved, projectId: garden.id);

      final reopened = await restart(store, storage);

      expect(reopened.tasksForProject(garden.id).map((t) => t.id),
          [moved.id]);
      expect(reopened.taskById(cleared.id)!.projectId, isNull);
      expect(reopened.taskById(store.tasks[2].id)!.projectId,
          'project_monday');
    });

    test('a deleted project stays deleted, its tasks stay unassigned',
        () async {
      final project = store.projects.first;
      final attached = store.tasksForProject(project.id).map((t) => t.id);
      store.deleteProject(project);

      final reopened = await restart(store, storage);

      expect(reopened.projectById(project.id), isNull);
      expect(reopened.projects, hasLength(1));
      for (final id in attached) {
        expect(reopened.taskById(id)!.projectId, isNull);
      }
      // Nothing stale was saved.
      final saved = jsonDecode(storage.snapshot!) as Map<String, dynamic>;
      expect(jsonEncode(saved['tasks']), isNot(contains(project.id)));
    });

    test('seed projects are not duplicated across launches', () async {
      var reopened = store;
      for (var i = 0; i < 3; i++) {
        reopened = await restart(reopened, storage);
      }

      expect(reopened.projects.map((p) => p.name), ['MONDAY', 'Portfolio']);
    });

    test('a snapshot pointing at a missing project is repaired on load',
        () async {
      final saved = jsonDecode(storage.snapshot!) as Map<String, dynamic>;
      (saved['projects'] as List).removeAt(0); // project_monday
      storage.snapshot = jsonEncode(saved);

      final reopened = await AppStore.open(storage);

      expect(reopened.tasks, hasLength(3));
      expect(
        reopened.tasks.where((t) => t.projectId == 'project_monday'),
        isEmpty,
      );
      expect(reopened.tasks.where((t) => t.projectId == 'project_portfolio'),
          hasLength(1));
    });

    test('project ids never collide after a restart', () async {
      final before = store.addProject(name: 'Before');

      final after = (await restart(store, storage)).addProject(name: 'After');

      expect(after.id, isNot(before.id));
    });
  });

  group('projects screen', () {
    testWidgets('lists every project from the store', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const ProjectsScreen()));

      expect(find.text('MONDAY'), findsOneWidget);
      expect(find.text('Portfolio'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no projects',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed)..projects.clear();

      await tester.pumpWidget(hostScreen(store, const ProjectsScreen()));

      expect(find.text('No projects yet'), findsOneWidget);
    });

    testWidgets('creating a project from the sheet lists it immediately',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const ProjectsScreen()));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('New project'), findsOneWidget);
      // The create form does not offer a colour.
      expect(find.text('Colour'), findsNothing);

      await tester.enterText(
          find.widgetWithText(TextField, 'Name your project'), '  Garden  ');
      await tester.enterText(
          find.widgetWithText(TextField, 'Add a little more detail...'),
          'Raised beds');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create project'));
      await tester.pumpAndSettle();

      expect(find.text('New project'), findsNothing);
      expect(find.text('Garden'), findsOneWidget);
      expect(find.text('Raised beds'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(store.projects.last.name, 'Garden');
    });

    testWidgets('a blank project name cannot be saved', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const ProjectsScreen()));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Name your project'), '   ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create project'));
      await tester.pumpAndSettle();

      expect(find.text('New project'), findsOneWidget);
      expect(store.projects, hasLength(2));
    });

    testWidgets('tapping a project opens its detail', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(store, const ProjectsScreen()));
      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectDetailScreen), findsOneWidget);
      expect(find.text('Send portfolio update'), findsOneWidget);
    });

    testWidgets('long-press asks, then deletes from the list',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final taskCount = store.tasks.length;

      await tester.pumpWidget(hostScreen(store, const ProjectsScreen()));
      await tester.longPress(find.text('Portfolio'));
      await tester.pumpAndSettle();
      expect(find.text('Delete project?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.projects, hasLength(2));

      await tester.longPress(find.text('Portfolio'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Portfolio'), findsNothing);
      expect(find.text('01'), findsOneWidget);
      expect(store.tasks, hasLength(taskCount));
    });
  });

  group('project detail', () {
    testWidgets('shows name, description, colour and its tasks',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(
          store, const ProjectDetailScreen(projectId: 'project_monday')));

      // The header draws the title with the design's green full stop.
      expect(find.text('MONDAY.', findRichText: true), findsOneWidget);
      expect(find.text('Product design and development'), findsOneWidget);
      expect(find.text('Colour'), findsOneWidget);
      expect(find.text('Sage'), findsOneWidget);
      expect(find.text('Review MONDAY wireframes'), findsOneWidget);
      expect(find.text('Organize project notes'), findsOneWidget);
      expect(find.text('Send portfolio update'), findsNothing);
    });

    testWidgets('shows the empty state for a project with no tasks',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final empty = store.addProject(name: 'Empty');

      await tester.pumpWidget(
          hostScreen(store, ProjectDetailScreen(projectId: empty.id)));

      expect(find.text('No tasks here yet'), findsOneWidget);
    });

    testWidgets('task membership changes show up immediately',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final garden = store.addProject(name: 'Garden');
      final task = store.tasks.first;

      await tester.pumpWidget(
          hostScreen(store, ProjectDetailScreen(projectId: garden.id)));
      expect(find.text(task.title), findsNothing);

      store.updateTask(task, projectId: garden.id);
      await tester.pumpAndSettle();
      expect(find.text(task.title), findsOneWidget);

      store.updateTask(task, projectId: 'project_portfolio');
      await tester.pumpAndSettle();
      expect(find.text(task.title), findsNothing);

      store.updateTask(task, projectId: garden.id);
      await tester.pumpAndSettle();
      store.updateTask(task, clearProject: true);
      await tester.pumpAndSettle();
      expect(find.text(task.title), findsNothing);
      expect(find.text('No tasks here yet'), findsOneWidget);
    });

    testWidgets('the edit sheet updates the project', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final project = store.projectById('project_portfolio')!;

      await tester.pumpWidget(hostScreen(
          store, const ProjectDetailScreen(projectId: 'project_portfolio')));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Edit project'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Portfolio'), 'Portfolio 2026');
      await tester.enterText(
          find.widgetWithText(TextField, 'Personal work and updates'),
          'Case studies');
      // Colour: Lilac -> Sage.
      await tester.tap(find.descendant(
          of: find.byType(BottomSheet), matching: find.text('Lilac')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Edit project'), findsNothing);
      expect(project.name, 'Portfolio 2026');
      expect(project.description, 'Case studies');
      expect(project.tint, TileTint.sage);
      expect(find.text('Portfolio 2026.', findRichText: true), findsOneWidget);
      expect(find.text('Case studies'), findsOneWidget);
    });

    testWidgets('the edit sheet will not save a blank name', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(
          store, const ProjectDetailScreen(projectId: 'project_monday')));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'MONDAY'), ' ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Edit project'), findsOneWidget);
      expect(store.projectById('project_monday')!.name, 'MONDAY');
    });

    testWidgets('the colour row changes the tint', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(
          store, const ProjectDetailScreen(projectId: 'project_monday')));
      await tester.tap(find.text('Colour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lilac'));
      await tester.pumpAndSettle();

      expect(store.projectById('project_monday')!.tint, TileTint.lilac);
      expect(find.text('Lilac'), findsOneWidget);
    });

    testWidgets('deleting asks first, closes, and keeps the tasks',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);
      final attached = store.tasksForProject('project_monday');

      await tester.pumpWidget(hostScreen(store, const ProjectsScreen()));
      await tester.tap(find.text('MONDAY'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete project'));
      await tester.pumpAndSettle();
      expect(find.text('Delete project?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectDetailScreen), findsNothing);
      expect(find.text('MONDAY'), findsNothing);
      for (final task in attached) {
        expect(store.taskById(task.id)!.projectId, isNull);
      }
    });

    testWidgets('reports a project deleted while open', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: seed);

      await tester.pumpWidget(hostScreen(
          store, const ProjectDetailScreen(projectId: 'project_monday')));
      store.deleteProject(store.projectById('project_monday')!);
      await tester.pumpAndSettle();

      expect(find.text('This project is no longer in your workspace.'),
          findsOneWidget);
    });
  });
}
