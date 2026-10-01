import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/main.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/widgets/task_row.dart';

void main() {
  testWidgets('shell opens on Home with the four navigation tabs',
      (tester) async {
    await tester.pumpWidget(const MondayApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text("Today's focus"), findsOneWidget);
  });

  testWidgets('tapping a tab swaps the visible screen', (tester) async {
    await tester.pumpWidget(const MondayApp());

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Everything else, in one place.'), findsOneWidget);
  });

  testWidgets('checking a task off removes it from the open list',
      (tester) async {
    await tester.pumpWidget(const MondayApp());

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskRow), findsNWidgets(3));

    await tester.tap(find.byType(MondayCheckbox).first);
    await tester.pumpAndSettle();

    // The default "All" filter shows open tasks only.
    expect(find.byType(TaskRow), findsNWidgets(2));
  });

  test('store filters tasks by due date', () {
    final seed = DateTime(2026, 10, 1, 9);
    final store = AppStore(seedDate: seed);

    expect(store.tasksFor(TaskFilter.all, now: seed), hasLength(3));
    expect(store.tasksFor(TaskFilter.today, now: seed), hasLength(2));
    expect(store.tasksFor(TaskFilter.upcoming, now: seed), hasLength(1));
    expect(store.tasksFor(TaskFilter.done, now: seed), isEmpty);

    store.toggleTask(store.tasks.first);

    expect(store.tasksFor(TaskFilter.all, now: seed), hasLength(2));
    expect(store.tasksFor(TaskFilter.done, now: seed), hasLength(1));
  });

  test('theme mode toggles between light and dark', () {
    final store = AppStore(seedDate: DateTime(2026, 10, 1));

    expect(store.themeMode, ThemeMode.light);
    store.toggleThemeMode();
    expect(store.themeMode, ThemeMode.dark);
    expect(store.isDarkMode, isTrue);
  });
}
