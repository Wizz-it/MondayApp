import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mondayapp/assistant/ai_service.dart';
import 'package:mondayapp/assistant/assistant_context.dart';
import 'package:mondayapp/assistant/fake_ai_service.dart';

final context = AssistantContext(DateTime(2026, 10, 3, 10));

const createTask = {
  'action': 'create_task',
  'title': 'Belajar Flutter',
  'date': {'kind': 'tomorrow'},
  'time': {'hour': 7, 'minute': 0, 'daypart': null},
  'project': null,
};

void main() {
  test('returns the canned answer as JSON text', () async {
    final ai = FakeAIService(
      responses: {'besok jam 7 belajar Flutter': createTask},
    );

    final answer = await ai.interpret('besok jam 7 belajar Flutter', context);

    expect(jsonDecode(answer), createTask);
  });

  test('matches transcripts ignoring case and surrounding spaces', () async {
    final ai = FakeAIService(responses: {'Catat: beli susu': createTask});

    expect(jsonDecode(await ai.interpret('  catat: BELI SUSU ', context)),
        createTask);
  });

  test('a string answer is passed back untouched', () async {
    final ai = FakeAIService(responses: {'x': 'Sure! {not json'});

    expect(await ai.interpret('x', context), 'Sure! {not json');
  });

  test('an exception answer is thrown', () {
    final ai = FakeAIService(responses: {
      'x': const AIServiceException(AIFailure.timeout),
    });

    expect(
      ai.interpret('x', context),
      throwsA(isA<AIServiceException>()
          .having((e) => e.failure, 'failure', AIFailure.timeout)),
    );
  });

  test('anything else gets the fallback, never an interpretation', () async {
    final ai = FakeAIService(responses: {'besok jam 7': createTask});

    // Looks like a command, but nothing was canned for it.
    final answer = await ai.interpret('tambahkan task lari besok', context);

    expect(jsonDecode(answer), containsPair('action', 'unsupported'));
  });

  test('the fallback can be replaced', () async {
    final ai = FakeAIService(fallback: 'garbage');

    expect(await ai.interpret('anything', context), 'garbage');
  });

  test('respond adds or replaces an answer', () async {
    final ai = FakeAIService()..respond('x', {'action': 'clarify', 'question': 'Kapan?'});

    expect(jsonDecode(await ai.interpret('x', context)),
        {'action': 'clarify', 'question': 'Kapan?'});
  });

  test('records every call with its context', () async {
    final ai = FakeAIService();

    await ai.interpret('satu', context);
    await ai.interpret('dua', context);

    expect(ai.calls.map((c) => c.transcript), ['satu', 'dua']);
    expect(ai.calls.first.context, same(context));
  });

  test('a gate holds the answer until opened', () async {
    final ai = FakeAIService(responses: {'x': createTask})
      ..gate = Completer<void>();
    var answered = false;

    final pending = ai.interpret('x', context).then((_) => answered = true);
    await Future<void>.delayed(Duration.zero);
    expect(answered, isFalse);

    ai.gate!.complete();
    await pending;
    expect(answered, isTrue);
  });

  test('any provider can stand behind the interface', () async {
    final AIService provider = _EchoProvider();

    final answer = await provider.interpret('beli susu', context);

    expect(jsonDecode(answer), {'action': 'capture_inbox', 'text': 'beli susu'});
  });
}

/// A stand-in for a real provider such as Groq: same contract, different
/// behaviour.
class _EchoProvider implements AIService {
  @override
  Future<String> interpret(String transcript, AssistantContext context) async =>
      jsonEncode({'action': 'capture_inbox', 'text': transcript});
}
