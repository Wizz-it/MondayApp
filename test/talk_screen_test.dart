import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/assistant_controller.dart';
import 'package:mondayapp/assistant/fake_ai_service.dart';
import 'package:mondayapp/screens/talk_screen.dart';
import 'package:mondayapp/services/app_store.dart';
import 'package:mondayapp/theme/app_theme.dart';

/// Saturday 3 October 2026, 10:00 local.
final now = DateTime(2026, 10, 3, 10);

Widget host(AppStore store, {AssistantController? assistant}) {
  return AppScope(
    store: store,
    child: MaterialApp(
      theme: mondayLightTheme,
      home: TalkScreen(assistant: assistant),
    ),
  );
}

/// The orb animates forever, so settle with a few timed frames instead.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Reply buttons can sit below the fold; scroll to them like a user would.
Future<void> tapReply(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await settle(tester);
}

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.arrow_forward));
  await settle(tester);
}

void main() {
  late AppStore store;
  late FakeAIService ai;
  late AssistantController assistant;

  setUp(() {
    store = AppStore(seedDate: now);
    ai = FakeAIService(responses: {
      'besok jam 7 belajar Flutter': {
        'action': 'create_task',
        'title': 'Belajar Flutter',
        'date': {'kind': 'tomorrow'},
        'time': {'hour': 7, 'minute': 0, 'daypart': null},
        'project': null,
      },
      'siram tanaman proyek Garden': {
        'action': 'create_task',
        'title': 'Siram tanaman',
        'date': {'kind': 'tomorrow'},
        'project': 'Garden',
      },
      'meeting Jumat jam 2': {
        'action': 'create_event',
        'title': 'Meeting',
        'date': {'kind': 'weekday', 'weekday': 'friday'},
        'time': {'hour': 2},
      },
    });
    assistant = AssistantController(store: store, ai: ai, clock: () => now);
  });

  tearDown(() => assistant.dispose());

  testWidgets('without an assistant, typed text still goes to the inbox',
      (tester) async {
    await tester.pumpWidget(host(store));

    await send(tester, 'beli susu');

    expect(store.inboxNewestFirst.single.text, 'beli susu');
    expect(find.text('Saved to your inbox.'), findsOneWidget);
    expect(ai.calls, isEmpty);
  });

  testWidgets('with an assistant, a request is carried out and answered',
      (tester) async {
    await tester.pumpWidget(host(store, assistant: assistant));

    await send(tester, 'besok jam 7 belajar Flutter');

    expect(find.text('"besok jam 7 belajar Flutter"'), findsOneWidget);
    expect(
      find.text('Task Belajar Flutter ditambahkan untuk 4 Oktober, '
          'dengan pengingat pukul 07.00.'),
      findsOneWidget,
    );
    expect(store.tasks.last.reminder, DateTime(2026, 10, 4, 7));
    expect(store.inbox, isEmpty, reason: 'not also captured');
    expect(find.text('Saved to your inbox.'), findsNothing);
  });

  testWidgets('shows processing and blocks sending meanwhile', (tester) async {
    ai.gate = Completer<void>();
    await tester.pumpWidget(host(store, assistant: assistant));

    await send(tester, 'besok jam 7 belajar Flutter');
    expect(find.text('MONDAY sedang memproses...'), findsOneWidget);

    await send(tester, 'meeting Jumat jam 2');
    expect(ai.calls, hasLength(1));

    ai.gate!.complete();
    await settle(tester);
    expect(find.text('MONDAY sedang memproses...'), findsNothing);
    expect(find.textContaining('Task Belajar Flutter'), findsOneWidget);
  });

  testWidgets('a clarification is shown as a question', (tester) async {
    await tester.pumpWidget(host(store, assistant: assistant));

    await send(tester, 'meeting Jumat jam 2');

    expect(find.text('Maksudnya pukul 02.00 atau 14.00?'), findsOneWidget);
    expect(store.eventsOn(DateTime(2026, 10, 9)), isEmpty);
  });

  testWidgets('a confirmation runs only when accepted', (tester) async {
    final tasks = store.tasks.length;
    await tester.pumpWidget(host(store, assistant: assistant));

    await send(tester, 'siram tanaman proyek Garden');

    expect(
      find.text('Proyek Garden tidak ditemukan. '
          'Simpan task Siram tanaman tanpa proyek?'),
      findsOneWidget,
    );
    expect(store.tasks, hasLength(tasks));

    await tapReply(tester, 'Simpan tanpa proyek');

    expect(find.text('Task Siram tanaman ditambahkan tanpa proyek untuk '
        '4 Oktober.'), findsOneWidget);
    expect(store.tasks.last.projectId, isNull);
    expect(store.projects, hasLength(2));
  });

  testWidgets('a confirmation can be cancelled', (tester) async {
    final tasks = store.tasks.length;
    await tester.pumpWidget(host(store, assistant: assistant));

    await send(tester, 'siram tanaman proyek Garden');
    await tapReply(tester, 'Batal');

    expect(find.textContaining('Proyek Garden'), findsNothing);
    expect(store.tasks, hasLength(tasks));
  });

  testWidgets('a failure offers to keep the words in the inbox',
      (tester) async {
    await tester.pumpWidget(host(store, assistant: assistant));

    await send(tester, 'cuaca hari ini?');

    expect(find.text('Maaf, permintaan itu belum bisa aku bantu.'),
        findsOneWidget);
    await tapReply(tester, 'Simpan ke Inbox');

    expect(find.text('Sudah dicatat ke Inbox.'), findsOneWidget);
    expect(store.inboxNewestFirst.single.text, 'cuaca hari ini?');
  });
}
