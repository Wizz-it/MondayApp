import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/screens/settings_screen.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/theme/app_theme.dart';

void main() {
  testWidgets('appearance control switches the stored theme mode',
      (tester) async {
    final store = AppStore(seedDate: DateTime(2026, 10, 1));

    await tester.pumpWidget(
      AppScope(
        store: store,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => MaterialApp(
            theme: mondayLightTheme,
            darkTheme: mondayDarkTheme,
            themeMode: store.themeMode,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );

    expect(find.text('Light mode'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();

    expect(store.themeMode, ThemeMode.dark);
    expect(find.text('Dark mode'), findsOneWidget);
  });

  testWidgets('notifications switch writes back to the store', (tester) async {
    final store = AppStore(seedDate: DateTime(2026, 10, 1));

    await tester.pumpWidget(
      AppScope(
        store: store,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => MaterialApp(
            theme: mondayLightTheme,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );

    expect(store.notificationsEnabled, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(store.notificationsEnabled, isFalse);
  });
}
