import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/main.dart';
import 'package:mondayapp/models/task.dart';
import 'package:mondayapp/screens/home_screen.dart';
import 'package:mondayapp/screens/task_detail_screen.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/theme/app_theme.dart';
import 'package:mondayapp/widgets/task_row.dart';

/// Hosts a single screen against a real [AppStore], the same way the app wires
/// itself up in `main.dart`.
Widget hostScreen(AppStore store, Widget child) {
  return AppScope(
    store: store,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        theme: mondayLightTheme,
        darkTheme: mondayDarkTheme,
        themeMode: store.themeMode,
        home: child,
      ),
    ),
  );
}

/// The default 800x600 test surface clips these screens, and a ListView does
/// not build what it cannot show. Tests that reach below the fold ask for a
/// phone-shaped surface tall enough to lay the whole screen out.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(440, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('store task operations', () {
    late AppStore store;
    final seed = DateTime(2026, 10, 1, 9);

    setUp(() => store = AppStore(seedDate: seed));

    test('addTask appends and is retrievable by id', () {
      final before = store.tasks.length;
      final task = store.addTask(title: 'Write the brief', dueDate: seed);

      expect(store.tasks.length, before + 1);
      expect(store.taskById(task.id), same(task));
      expect(task.isDone, isFalse);
      expect(task.priority, TaskPriority.normal);
    });

    test('taskById returns null once the task is deleted', () {
      final task = store.addTask(title: 'Temporary');
      store.deleteTask(task);

      expect(store.taskById(task.id), isNull);
    });

    test('updateTask writes every supported field', () {
      final task = store.addTask(title: 'Draft');
      final due = DateTime(2026, 10, 5);
      final remind = DateTime(2026, 10, 5, 8, 30);

      store.updateTask(
        task,
        title: 'Final draft',
        description: 'Second pass',
        dueDate: due,
        reminder: remind,
        priority: TaskPriority.high,
        projectId: 'project_monday',
      );

      expect(task.title, 'Final draft');
      expect(task.description, 'Second pass');
      expect(task.dueDate, due);
      expect(task.reminder, remind);
      expect(task.priority, TaskPriority.high);
      expect(task.projectId, 'project_monday');
    });

    test('updateTask clears date, reminder and project', () {
      final task = store.addTask(title: 'Clear me', dueDate: seed);
      store.updateTask(
        task,
        reminder: seed,
        projectId: 'project_monday',
      );

      store.updateTask(
        task,
        clearDueDate: true,
        clearReminder: true,
        clearProject: true,
      );

      expect(task.dueDate, isNull);
      expect(task.reminder, isNull);
      expect(task.projectId, isNull);
    });

    test('toggling moves a task between the open and done filters', () {
      final task = store.tasks.first;

      expect(store.tasksFor(TaskFilter.done, now: seed), isEmpty);

      store.toggleTask(task);
      expect(store.tasksFor(TaskFilter.done, now: seed), contains(task));
      expect(store.tasksFor(TaskFilter.all, now: seed), isNot(contains(task)));

      store.toggleTask(task);
      expect(store.tasksFor(TaskFilter.done, now: seed), isEmpty);
      expect(store.tasksFor(TaskFilter.all, now: seed), contains(task));
    });

    test('deleting a project detaches its tasks but keeps them', () {
      final project = store.projects.first;
      final attached = store.tasksForProject(project.id).toList();
      expect(attached, isNotEmpty);

      store.deleteProject(project);

      for (final task in attached) {
        expect(store.tasks, contains(task));
        expect(task.projectId, isNull);
      }
    });
  });

  group('task flows in the app', () {
    testWidgets('creating a task from the sheet shows it in the list',
        (tester) async {
      await tester.pumpWidget(const MondayApp());

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskRow), findsNWidgets(3));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'What needs to get done?'),
        'Ship the task feature',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      expect(find.text('New task'), findsNothing);
      expect(find.byType(TaskRow), findsNWidgets(4));
      expect(find.text('Ship the task feature'), findsOneWidget);
    });

    testWidgets('the section counter follows the real task count',
        (tester) async {
      await tester.pumpWidget(const MondayApp());

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('03'), findsOneWidget);

      await tester.tap(find.byType(MondayCheckbox).first);
      await tester.pumpAndSettle();

      // "All" shows open tasks, so completing one drops the count.
      expect(find.text('02'), findsOneWidget);
    });

    testWidgets('completing a task on Tasks updates Home immediately',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(const MondayApp());
      await tester.pumpAndSettle();

      final homeList = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(ListView),
      );

      // Home seeds two tasks due today.
      expect(find.descendant(of: homeList, matching: find.text('2 tasks')),
          findsOneWidget);

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MondayCheckbox).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.descendant(of: homeList, matching: find.text('1 task')),
          findsOneWidget);
    });

    testWidgets('editing a task from detail updates the list', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: DateTime(2026, 10, 1, 9));
      final task = store.tasks.first;

      await tester.pumpWidget(
        hostScreen(store, TaskDetailScreen(taskId: task.id)),
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Review MONDAY wireframes'),
        'Review the final wireframes',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      // The sheet closed and the stored task carries the new title. The
      // heading itself is rich text (it carries the accent full stop), so the
      // model is the thing worth asserting on here.
      expect(find.text('Edit task'), findsNothing);
      expect(task.title, 'Review the final wireframes');
    });

    testWidgets('detail toggles completion through the store', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: DateTime(2026, 10, 1, 9));
      final task = store.tasks.first;

      await tester.pumpWidget(
        hostScreen(store, TaskDetailScreen(taskId: task.id)),
      );

      expect(find.text('Mark as done'), findsOneWidget);

      await tester.tap(find.text('Mark as done'));
      await tester.pumpAndSettle();

      expect(task.isDone, isTrue);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('deleting from detail asks first, then removes the task',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: DateTime(2026, 10, 1, 9));
      final task = store.tasks.first;
      final before = store.tasks.length;

      await tester.pumpWidget(
        hostScreen(store, TaskDetailScreen(taskId: task.id)),
      );

      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      expect(find.text('Delete task?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.tasks.length, before);

      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(store.tasks.length, before - 1);
      expect(store.taskById(task.id), isNull);
    });

    testWidgets('detail reports a task that no longer exists', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: DateTime(2026, 10, 1, 9));
      final task = store.tasks.first;

      await tester.pumpWidget(
        hostScreen(store, TaskDetailScreen(taskId: task.id)),
      );

      store.deleteTask(task);
      await tester.pumpAndSettle();

      expect(
        find.text('This task is no longer in your list.'),
        findsOneWidget,
      );
    });

    testWidgets('assigning a project from detail updates the row',
        (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: DateTime(2026, 10, 1, 9));
      final task = store.addTask(title: 'Unassigned work');

      await tester.pumpWidget(
        hostScreen(store, TaskDetailScreen(taskId: task.id)),
      );

      expect(find.text('No project'), findsOneWidget);

      await tester.tap(find.text('Project'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Portfolio').last);
      await tester.pumpAndSettle();

      expect(task.projectId, 'project_portfolio');
      expect(find.text('Portfolio'), findsOneWidget);
    });

    testWidgets('priority can be changed from detail', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: DateTime(2026, 10, 1, 9));
      final task = store.tasks.first;

      await tester.pumpWidget(
        hostScreen(store, TaskDetailScreen(taskId: task.id)),
      );

      expect(find.text('Normal'), findsOneWidget);

      await tester.tap(find.text('Priority'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();

      expect(task.priority, TaskPriority.high);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('clearing a due date empties the row', (tester) async {
      useTallSurface(tester);
      final store = AppStore(seedDate: DateTime(2026, 10, 1, 9));
      final task = store.tasks.first;
      expect(task.dueDate, isNotNull);

      await tester.pumpWidget(
        hostScreen(store, TaskDetailScreen(taskId: task.id)),
      );

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(task.dueDate, isNull);
      expect(find.text('Not set'), findsNWidgets(2));
    });

    testWidgets('the Done filter lists completed tasks', (tester) async {
      await tester.pumpWidget(const MondayApp());

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MondayCheckbox).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskRow), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
    });

    testWidgets('empty state appears when a filter has no tasks',
        (tester) async {
      await tester.pumpWidget(const MondayApp());

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing finished yet'), findsOneWidget);
      expect(find.byType(TaskRow), findsNothing);
    });
  });
}
