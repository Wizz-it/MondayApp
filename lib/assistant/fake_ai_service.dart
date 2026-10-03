import 'dart:async';
import 'dart:convert';

import 'ai_service.dart';
import 'assistant_context.dart';

/// An [AIService] that only plays back canned answers. No interpretation of
/// any kind happens here; it exists so the assistant flow can be developed
/// and tested without a provider or a network.
///
/// [responses] maps a transcript to what the "model" answers:
/// * a `Map` or `List` — sent back as JSON text;
/// * a `String` — sent back as-is, so malformed output can be simulated;
/// * an [Exception] — thrown, to simulate a provider failure.
///
/// Transcripts match after trimming and ignoring case. Anything without a
/// canned answer gets [fallback], by default an `unsupported` action.
class FakeAIService implements AIService {
  FakeAIService({
    Map<String, Object> responses = const {},
    this.fallback = const {
      'action': 'unsupported',
      'reason': 'FakeAIService has no canned response',
    },
  }) : _responses = {
          for (final MapEntry(:key, :value) in responses.entries)
            _normalize(key): value,
        };

  final Map<String, Object> _responses;
  final Object fallback;

  /// Every call, in order, for tests to inspect.
  final List<({String transcript, AssistantContext context})> calls = [];

  /// When set, answers wait for it to complete — to observe the in-between
  /// "processing" state.
  Completer<void>? gate;

  /// Adds or replaces a canned answer.
  void respond(String transcript, Object response) =>
      _responses[_normalize(transcript)] = response;

  @override
  Future<String> interpret(String transcript, AssistantContext context) async {
    calls.add((transcript: transcript, context: context));
    await gate?.future;

    final response = _responses[_normalize(transcript)] ?? fallback;
    return switch (response) {
      Exception() => throw response,
      String() => response,
      _ => jsonEncode(response),
    };
  }

  static String _normalize(String transcript) =>
      transcript.trim().toLowerCase();
}
