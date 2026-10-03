import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/inbox_item.dart';
import '../models/note.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/tile_tint.dart';
import '../utils/date_labels.dart';
import 'app_storage.dart';

/// Which slice of the task list the Tasks screen is showing.
enum TaskFilter {
  all('All'),
  today('Today'),
  upcoming('Upcoming'),
  done('Done');

  const TaskFilter(this.label);
  final String label;
}

/// A single store for the whole app, and the only thing screens talk to.
///
/// State lives in memory. When the store is given an [AppStorage], every
/// mutation also writes a JSON snapshot of that state, and [AppStore.open]
/// reads it back on the next launch. Screens never touch storage directly.
class AppStore extends ChangeNotifier {
  /// A seeded store. Without [storage] nothing is saved, which is what tests
  /// that only exercise behaviour want.
  AppStore({DateTime? seedDate, this._storage}) {
    _seed(seedDate ?? DateTime.now());
  }

  AppStore._restored(Map<String, dynamic> json, this._storage) {
    _restore(json);
  }

  /// Loads the saved snapshot from [storage], or seeds and saves the default
  /// data when there is none yet (first launch).
  static Future<AppStore> open(AppStorage storage, {DateTime? seedDate}) async {
    final saved = await storage.read();
    if (saved != null) {
      try {
        return AppStore._restored(
          jsonDecode(saved) as Map<String, dynamic>,
          storage,
        );
      } catch (error) {
        // Unreadable snapshot. Starting over beats refusing to open, and the
        // fresh seed below replaces it.
        debugPrint('MONDAY: could not read saved state, reseeding: $error');
      }
    }
    final store = AppStore(seedDate: seedDate, storage: storage).._queueSave();
    await store.flush();
    return store;
  }

  // Persistence ------------------------------------------------------------

  /// Bump when the snapshot shape changes in a way old readers can't handle.
  static const schemaVersion = 1;

  final AppStorage? _storage;
  Future<void> _writes = Future.value();
  bool _savePending = false;

  /// Notifies listeners and queues a save. Saves are batched to one write per
  /// microtask, so a handler that changes several things writes once.
  void _commit() {
    notifyListeners();
    _queueSave();
  }

  void _queueSave() {
    if (_storage == null || _savePending) return;
    _savePending = true;
    scheduleMicrotask(_save);
  }

  void _save() {
    final storage = _storage;
    // Already written by an explicit flush().
    if (storage == null || !_savePending) return;
    _savePending = false;
    // Encode now, so the write carries the state as of this moment even if it
    // has to wait behind an earlier write.
    final snapshot = jsonEncode(toJson());
    _writes = _writes.then((_) => storage.write(snapshot)).catchError(
          (Object error) => debugPrint('MONDAY: could not save state: $error'),
        );
  }

  /// Completes once every change made so far has reached storage.
  Future<void> flush() {
    if (_savePending) _save();
    return _writes;
  }

  Map<String, dynamic> toJson() => {
        'version': schemaVersion,
        'nextId': _nextId,
        'preferences': {
          'themeMode': themeMode.name,
          'notificationsEnabled': notificationsEnabled,
          'notificationPermissionRequested': notificationPermissionRequested,
        },
        'projects': [for (final p in projects) p.toJson()],
        'tasks': [for (final t in tasks) t.toJson()],
        'events': [for (final e in events) e.toJson()],
        'notes': [for (final n in notes) n.toJson()],
        'inbox': [for (final i in inbox) i.toJson()],
      };

  void _restore(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        (json[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

    final prefs = json['preferences'] as Map<String, dynamic>? ?? const {};
    themeMode =
        ThemeMode.values.asNameMap()[prefs['themeMode']] ?? ThemeMode.light;
    notificationsEnabled = prefs['notificationsEnabled'] as bool? ?? true;
    notificationPermissionRequested =
        prefs['notificationPermissionRequested'] as bool? ?? false;

    projects.addAll(list('projects').map(Project.fromJson));
    tasks.addAll(list('tasks').map(Task.fromJson));
    events.addAll(list('events').map(CalendarEvent.fromJson));
    notes.addAll(list('notes').map(Note.fromJson));
    inbox.addAll(list('inbox').map(InboxItem.fromJson));

    // Never hand out an id that is already taken, even if the saved counter
    // is missing or behind.
    _nextId = math.max(json['nextId'] as int? ?? 0, _idFloor());
  }

  /// One past the highest numeric id suffix in use (`task_7` → 8).
  int _idFloor() {
    final ids = [
      ...tasks.map((t) => t.id),
      ...events.map((e) => e.id),
      ...projects.map((p) => p.id),
      ...notes.map((n) => n.id),
      ...inbox.map((i) => i.id),
    ];
    var floor = 0;
    for (final id in ids) {
      final n = int.tryParse(id.substring(id.lastIndexOf('_') + 1));
      if (n != null && n >= floor) floor = n + 1;
    }
    return floor;
  }

  // Preferences ------------------------------------------------------------

  String userName = 'Alex';
  ThemeMode themeMode = ThemeMode.light;
  bool notificationsEnabled = true;

  /// Whether the app has already shown the system notification prompt, so
  /// it is only ever shown once without the user asking.
  bool notificationPermissionRequested = false;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  void toggleThemeMode() {
    themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    _commit();
  }

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
    _commit();
  }

  void markNotificationPermissionRequested() {
    notificationPermissionRequested = true;
    _commit();
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
    _commit();
    return task;
  }

  void toggleTask(Task task) {
    task.isDone = !task.isDone;
    _commit();
  }

  void updateTask(
    Task task, {
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? reminder,
    TaskPriority? priority,
    String? projectId,
    bool clearDueDate = false,
    bool clearReminder = false,
    bool clearProject = false,
  }) {
    if (title != null) task.title = title;
    if (description != null) task.description = description;
    if (dueDate != null) task.dueDate = dueDate;
    if (clearDueDate) task.dueDate = null;
    if (reminder != null) task.reminder = reminder;
    if (clearReminder) task.reminder = null;
    if (priority != null) task.priority = priority;
    if (projectId != null) task.projectId = projectId;
    if (clearProject) task.projectId = null;
    _commit();
  }

  /// Looks a task up by id. Detail screens hold an id rather than a reference
  /// so they notice when the task they were showing has been deleted.
  Task? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  void deleteTask(Task task) {
    tasks.remove(task);
    _commit();
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

  CalendarEvent addEvent({
    required String title,
    required DateTime start,
    String description = '',
  }) {
    final event = CalendarEvent(
      id: _id('event'),
      title: title,
      start: start,
      description: description,
    );
    events.add(event);
    _commit();
    return event;
  }

  /// Looks an event up by id, for the same reason as [taskById].
  CalendarEvent? eventById(String id) {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  void updateEvent(
    CalendarEvent event, {
    String? title,
    DateTime? start,
    String? description,
  }) {
    if (title != null) event.title = title;
    if (start != null) event.start = start;
    if (description != null) event.description = description;
    _commit();
  }

  void deleteEvent(CalendarEvent event) {
    events.remove(event);
    _commit();
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
    _commit();
  }

  void deleteProject(Project project) {
    projects.remove(project);
    for (final task in tasks) {
      if (task.projectId == project.id) task.projectId = null;
    }
    _commit();
  }

  // Notes ------------------------------------------------------------------

  void addNote({required String title, String body = ''}) {
    notes.add(Note(id: _id('note'), title: title, body: body));
    _commit();
  }

  void updateNote(Note note, {String? title, String? body}) {
    if (title != null) note.title = title;
    if (body != null) note.body = body;
    _commit();
  }

  void deleteNote(Note note) {
    notes.remove(note);
    _commit();
  }

  // Inbox ------------------------------------------------------------------

  void captureThought(String text) {
    inbox.add(InboxItem(
      id: _id('inbox'),
      text: text,
      capturedAt: DateTime.now(),
    ));
    _commit();
  }

  void deleteInboxItem(InboxItem item) {
    inbox.remove(item);
    _commit();
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
