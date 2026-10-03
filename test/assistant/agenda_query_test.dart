import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/agenda_query.dart';
import 'package:mondayapp/assistant/assistant_action.dart';
import 'package:mondayapp/services/app_store.dart';

/// Saturday 3 October 2026, 10:00 local. The seed puts two tasks and the
/// 14:30 "Project check-in" event on this day, and a third task two days on.
final now = DateTime(2026, 10, 3, 10);
final today = DateTime(2026, 10, 3);

const both = {AgendaPart.tasks, AgendaPart.events};

void main() {
  late AppStore store;
  late AgendaQuery query;

  setUp(() {
    store = AppStore(seedDate: now);
    query = AgendaQuery(store);
  });

  test('both tasks and events', () {
    final agenda = query.forDay(today, include: both);

    expect(agenda.day, today);
    expect(agenda.includesTasks, isTrue);
    expect(agenda.includesEvents, isTrue);
    expect(agenda.openTasks, const [
      AgendaTask(title: 'Review MONDAY wireframes', projectName: 'MONDAY'),
      AgendaTask(title: 'Send portfolio update', projectName: 'Portfolio'),
    ]);
    expect(agenda.events, [
      AgendaEvent(title: 'Project check-in', start: DateTime(2026, 10, 3, 14, 30)),
    ]);
    expect(agenda.completedTaskCount, 0);
  });

  test('tasks only', () {
    final agenda = query.forDay(today, include: const {AgendaPart.tasks});

    expect(agenda.openTasks, hasLength(2));
    expect(agenda.events, isEmpty);
    expect(agenda.includesEvents, isFalse);
  });

  test('events only', () {
    final agenda = query.forDay(today, include: const {AgendaPart.events});

    expect(agenda.events, hasLength(1));
    expect(agenda.openTasks, isEmpty);
    expect(agenda.completedTaskCount, 0);
    expect(agenda.includesTasks, isFalse);
  });

  test('completed tasks are counted, not listed', () {
    store.toggleTask(store.tasks.first);

    final agenda = query.forDay(today, include: both);

    expect(agenda.openTasks.map((t) => t.title), ['Send portfolio update']);
    expect(agenda.completedTaskCount, 1);
  });

  test('a reminder and a missing project are carried through', () {
    final task = store.addTask(title: 'Loose end', dueDate: today);
    store.updateTask(task, reminder: DateTime(2026, 10, 3, 18));

    final agenda = query.forDay(today, include: const {AgendaPart.tasks});

    expect(
      agenda.openTasks.last,
      AgendaTask(title: 'Loose end', reminder: DateTime(2026, 10, 3, 18)),
    );
  });

  test('events come in start order', () {
    store.addEvent(title: 'Late', start: DateTime(2026, 10, 3, 19));
    store.addEvent(title: 'Early', start: DateTime(2026, 10, 3, 8));

    final agenda = query.forDay(today, include: const {AgendaPart.events});

    expect(agenda.events.map((e) => e.title),
        ['Early', 'Project check-in', 'Late']);
  });

  test('another day', () {
    final agenda =
        query.forDay(DateTime(2026, 10, 5), include: both);

    expect(agenda.openTasks.map((t) => t.title), ['Organize project notes']);
    expect(agenda.events, isEmpty);
  });

  test('an empty day', () {
    final agenda = query.forDay(DateTime(2026, 10, 20), include: both);

    expect(agenda.openTasks, isEmpty);
    expect(agenda.events, isEmpty);
    expect(agenda.completedTaskCount, 0);
  });

  test('any time on the day finds that day', () {
    final agenda =
        query.forDay(DateTime(2026, 10, 3, 23, 59), include: both);

    expect(agenda.day, today);
    expect(agenda.openTasks, hasLength(2));
  });

  test('reading never changes the store', () {
    var notified = 0;
    store.addListener(() => notified++);
    final before = jsonEncode(store.toJson());

    query.forDay(today, include: both);
    query.forDay(DateTime(2026, 10, 5), include: both);

    expect(notified, 0);
    expect(jsonEncode(store.toJson()), before);
  });

  test('the snapshot cannot be changed by its reader', () {
    final agenda = query.forDay(today, include: both);

    expect(() => agenda.openTasks.clear(), throwsUnsupportedError);
    expect(() => agenda.events.clear(), throwsUnsupportedError);
    expect(() => agenda.include.clear(), throwsUnsupportedError);
  });
}
