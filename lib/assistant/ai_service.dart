import 'assistant_context.dart';

/// Turns what the user said into one structured action, as JSON text.
///
/// This is the only seam between MONDAY and a language model provider. A
/// provider (Groq, OpenAI, Claude, ...) implements it; nothing else changes.
/// An implementation:
/// * receives only the transcript and an [AssistantContext] — never store
///   data, ids or objects;
/// * returns the model's answer as text, untouched — [ActionParser] decides
///   whether it is valid, so a provider never needs to;
/// * never executes, saves or schedules anything;
/// * reports provider problems as [AIServiceException].
abstract interface class AIService {
  Future<String> interpret(String transcript, AssistantContext context);
}

/// Why a provider could not answer. Kept provider-neutral so the controller
/// can explain it without knowing which provider is behind it.
enum AIFailure {
  /// No network connection.
  offline,

  /// The provider took too long.
  timeout,

  /// Anything else: rate limits, outages, refusals, bad credentials.
  unavailable,
}

class AIServiceException implements Exception {
  const AIServiceException(this.failure, [this.message]);

  final AIFailure failure;

  /// For logs; not shown to the user.
  final String? message;

  @override
  String toString() => 'AIServiceException(${failure.name}: $message)';
}
