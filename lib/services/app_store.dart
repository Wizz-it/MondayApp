import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/inbox_item.dart';
import '../models/note.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/tile_tint.dart';
import '../utils/date_labels.dart';

/// Which slice of the task list the Tasks screen is showing.
enum TaskFilter {
  all('All'),
  today('Today'),
  upcoming('Upcoming'),
  done('Done');

  const TaskFilter(this.label);
  final String label;
}

/// A single in-memory store for the whole app.
///
/// This is deliberately simple: no persistence, no repositories, no DI. It
/// exists so the redesigned UI can behave the way the reference implies —
/// checkboxes toggle, counters move, empty states appear — and it is meant to
/// be replaced wholesale once a real data layer lands.
class AppStore extends ChangeNotifier {
  AppStore({DateTime? seedDate}) {
    _seed(seedDate ?? DateTime.now());
  }

  // Preferences ------------------------------------------------------------

  String userName = 'Alex';
  ThemeMode themeMode = ThemeMode.light;
  bool notificationsEnabled = true;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  void toggleThemeMode() {
    themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
    notifyListeners();
  }

  // Collections ------------------------------------------------------------

  final List<Task> tasks = [];
  final List<CalendarEvent> events = [];
  final List<Project> projects = [];
  final List<Note> notes = [];
  final List<InboxItem> inbox = [];

  int _nextId = 0;
  String _id(String prefix) => '${prefix}_${_nextId++}';

  void _seed(DateTime now) {
    final today = dayOf(now);

    projects.addAll([
      Project(
        id: 'project_monday',
        name: 'MONDAY',
        description: 'Product design and development',
      ),
      Project(
        id: 'project_portfolio',
        name: 'Portfolio',
        description: 'Personal work and updates',
        tint: TileTint.lilac,
      ),
    ]);

    tasks.addAll([
      Task(
        id: _id('task'),
        title: 'Review MONDAY wireframes',
        projectId: 'project_monday',
        dueDate: today,
      ),
      Task(
        id: _id('task'),
        title: 'Send portfolio update',
        projectId: 'project_portfolio',
        dueDate: today,
      ),
      Task(
        id: _id('task'),
        title: 'Organize project notes',
        projectId: 'project_monday',
        dueDate: today.add(const Duration(days: 2)),
      ),
    ]);

    events.add(
      CalendarEvent(
        id: _id('event'),
        title: 'Project check-in',
        start: today.add(const Duration(hours: 14, minutes: 30)),
      ),
    );

    notes.addAll([
      Note(
        id: _id('note'),
        title: 'Project ideas',
        body: 'Ideas for future MONDAY features.',
      ),
      Note(
        id: _id('note'),
        title: 'Meeting notes',
        body: 'A place for the important details.',
      ),
    ]);
  }

  // Tasks ------------------------------------------------------------------

  List<Task> get openTasks => tasks.where((t) => !t.isDone).toList();

  List<Task> tasksFor(TaskFilter filter, {DateTime? now}) {
    final today = dayOf(now ?? DateTime.now());
    switch (filter) {
      case TaskFilter.all:
        return tasks.where((t) => !t.isDone).toList();
      case TaskFilter.today:
        return tasks
            .where((t) =>
                !t.isDone && t.dueDate != null && isSameDay(t.dueDate!, today))
            .toList();
      case TaskFilter.upcoming:
        return tasks
            .where((t) =>
                !t.isDone &&
                t.dueDate != null &&
                dayOf(t.dueDate!).isAfter(today))
            .toList();
      case TaskFilter.done:
        return tasks.where((t) => t.isDone).toList();
    }
  }

  List<Task> tasksOn(DateTime day) => tasks
      .where((t) => t.dueDate != null && isSameDay(t.dueDate!, day))
      .toList();

  List<Task> tasksForProject(String projectId) =>
      tasks.where((t) => t.projectId == projectId).toList();

  Task addTask({
    required String title,
    DateTime? dueDate,
    String? projectId,
    String description = '',
  }) {
    final task = Task(
      id: _id('task'),
      title: title,
      description: description,
      projectId: projectId,
      dueDate: dueDate,
    );
    tasks.add(task);
    notifyListeners();
    return task;
  }

  void toggleTask(Task task) {
    task.isDone = !task.isDone;
    notifyListeners();
  }

  void updateTask(
    Task task, {
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? reminder,
    TaskPriority? priority,
    bool clearDueDate = false,
    bool clearReminder = false,
  }) {
    if (title != null) task.title = title;
    if (description != null) task.description = description;
    if (dueDate != null) task.dueDate = dueDate;
    if (clearDueDate) task.dueDate = null;
    if (reminder != null) task.reminder = reminder;
    if (clearReminder) task.reminder = null;
    if (priority != null) task.priority = priority;
    notifyListeners();
  }

  void deleteTask(Task task) {
    tasks.remove(task);
    notifyListeners();
  }

  // Events -----------------------------------------------------------------

  List<CalendarEvent> eventsOn(DateTime day) =>
      events.where((e) => isSameDay(e.start, day)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  List<CalendarEvent> get upcomingEvents {
    final now = DateTime.now();
    return events.where((e) => e.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  void addEvent({
    required String title,
    required DateTime start,
    String description = '',
  }) {
    events.add(CalendarEvent(
      id: _id('event'),
      title: title,
      start: start,
      description: description,
    ));
    notifyListeners();
  }

  void deleteEvent(CalendarEvent event) {
    events.remove(event);
    notifyListeners();
  }

  /// Days in [month] that have at least one task or event, for the calendar
  /// grid's activity dots.
  Set<int> activeDaysIn(DateTime month) {
    final days = <int>{};
    for (final e in events) {
      if (e.start.year == month.year && e.start.month == month.month) {
        days.add(e.start.day);
      }
    }
    for (final t in tasks) {
      final due = t.dueDate;
      if (due != null && due.year == month.year && due.month == month.month) {
        days.add(due.day);
      }
    }
    return days;
  }

  // Projects ---------------------------------------------------------------

  Project? projectById(String? id) {
    if (id == null) return null;
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  String? projectNameFor(Task task) => projectById(task.projectId)?.name;

  void addProject({required String name, String description = ''}) {
    projects.add(Project(
      id: _id('project'),
      name: name,
      description: description,
      tint: projects.length.isEven ? TileTint.sage : TileTint.lilac,
    ));
    notifyListeners();
  }

  void deleteProject(Project project) {
    projects.remove(project);
    for (final task in tasks) {
      if (task.projectId == project.id) task.projectId = null;
    }
    notifyListeners();
  }

  // Notes ------------------------------------------------------------------

  void addNote({required String title, String body = ''}) {
    notes.add(Note(id: _id('note'), title: title, body: body));
    notifyListeners();
  }

  void updateNote(Note note, {String? title, String? body}) {
    if (title != null) note.title = title;
    if (body != null) note.body = body;
    notifyListeners();
  }

  void deleteNote(Note note) {
    notes.remove(note);
    notifyListeners();
  }

  // Inbox ------------------------------------------------------------------

  void captureThought(String text) {
    inbox.add(InboxItem(
      id: _id('inbox'),
      text: text,
      capturedAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void deleteInboxItem(InboxItem item) {
    inbox.remove(item);
    notifyListeners();
  }
}

/// Exposes the [AppStore] to the widget tree and rebuilds dependents when it
/// changes. Read it with `AppScope.of(context)`.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!.notifier!;
  }

  /// Reads the store without subscribing — for event handlers.
  static AppStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!.notifier!;
  }
}
