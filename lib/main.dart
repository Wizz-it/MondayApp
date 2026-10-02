import 'package:flutter/material.dart';

import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/app_storage.dart';
import 'services/app_store.dart';
import 'theme/app_theme.dart';
import 'theme/palette.dart';
import 'widgets/monday_bottom_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load saved data before the first frame so the UI never shows seed data
  // that is about to be replaced. The platform splash covers the wait.
  final store = await AppStore.open(SharedPreferencesAppStorage());
  runApp(MondayApp(store: store));
}

class MondayApp extends StatefulWidget {
  /// Without a [store] the app runs on seeded, unsaved data (used by tests).
  const MondayApp({super.key, this.store});

  final AppStore? store;

  @override
  State<MondayApp> createState() => _MondayAppState();
}

class _MondayAppState extends State<MondayApp> {
  late final AppStore _store = widget.store ?? AppStore();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: _store,
      // The theme itself depends on store state, so the MaterialApp is rebuilt
      // from the same listenable rather than from an inherited lookup.
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MONDAY',
          theme: mondayLightTheme,
          darkTheme: mondayDarkTheme,
          themeMode: _store.themeMode,
          home: const MondayShell(),
        ),
      ),
    );
  }
}

/// The four-tab shell. Tabs keep their state and scroll position between
/// switches, which the previous list-swap approach did not.
class MondayShell extends StatefulWidget {
  const MondayShell({super.key});

  @override
  State<MondayShell> createState() => _MondayShellState();
}

class _MondayShellState extends State<MondayShell> {
  int _index = 0;

  static const _items = [
    MondayNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    MondayNavItem(
      icon: Icons.check_circle_outline,
      activeIcon: Icons.check_circle,
      label: 'Tasks',
    ),
    MondayNavItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_month,
      label: 'Calendar',
    ),
    MondayNavItem(
      icon: Icons.menu,
      activeIcon: Icons.menu,
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenTab: _goToTab),
          const TasksScreen(),
          const CalendarScreen(),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: MondayBottomNav(
        currentIndex: _index,
        items: _items,
        onSelected: _goToTab,
      ),
    );
  }

  void _goToTab(int index) => setState(() => _index = index);
}
