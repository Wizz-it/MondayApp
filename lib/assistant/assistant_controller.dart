import 'package:flutter/foundation.dart';

import '../services/app_store.dart';
import 'action_executor.dart';
import 'action_parser.dart';
import 'action_validator.dart';
import 'ai_service.dart';
import 'assistant_context.dart';
import 'date_resolver.dart';
import 'response_composer.dart';

// States --------------------------------------------------------------------

/// Where the current request stands. Every state after [AssistantIdle] keeps
/// the [transcript] it is about, so the UI can show it and offer to save it to
/// the Inbox instead.
sealed class AssistantState {
  const AssistantState();
}

final class AssistantIdle extends AssistantState {
  const AssistantIdle();
}

final class AssistantProcessing extends AssistantState {
  const AssistantProcessing(this.transcript);

  final String transcript;
}

/// The request was carried out (or answered, for a query).
final class AssistantSucceeded extends AssistantState {
  const AssistantSucceeded({
    required this.transcript,
    required this.result,
    required this.message,
  });

  final String transcript;
  final ExecutionResult result;
  final String message;
}

/// Ready to run, but only after the user says yes: call
/// [AssistantController.confirm] or [AssistantController.cancel].
final class AssistantNeedsConfirmation extends AssistantState {
  const AssistantNeedsConfirmation({
    required this.transcript,
    required this.action,
    required this.reasons,
    required this.message,
    required this.requestedAt,
  });

  final String transcript;

  /// Exactly what will run on confirmation.
  final ResolvedAction action;
  final List<ConfirmationReason> reasons;

  /// The question to show, in Indonesian.
  final String message;

  /// The clock reading the request was resolved with.
  final DateTime requestedAt;

  /// Confirming creates the task without the project the user named.
  bool get withoutProject => reasons.contains(ConfirmationReason.unknownProject);
}

/// The user needs to say more. The answer is a new request; nothing from this
/// one is remembered.
final class AssistantNeedsClarification extends AssistantState {
  const AssistantNeedsClarification({
    required this.transcript,
    required this.reason,
    required this.message,
    this.timeOptions = const [],
  });

  final String transcript;
  final ClarificationReason reason;

  /// The question to show, in Indonesian.
  final String message;

  /// The readings of an ambiguous hour, for quick replies.
  final List<ClockTime> timeOptions;
}

enum AssistantFailureKind {
  /// The AI provider could not answer (offline, timeout, outage).
  aiUnavailable,

  /// The answer was understood but can't be carried out, or wasn't
  /// understood at all (including malformed model output).
  rejected,

  /// Carrying out the action failed.
  executionFailed,
}

/// Nothing was done. [AssistantController.saveToInbox] keeps the user's words
/// anyway.
final class AssistantFailed extends AssistantState {
  const AssistantFailed({
    required this.transcript,
    required this.kind,
    required this.message,
    required this.requestedAt,
    this.rejection,
  });

  final String transcript;
  final AssistantFailureKind kind;

  /// The explanation to show, in Indonesian.
  final String message;
  final DateTime requestedAt;

  /// Why, when [kind] is [AssistantFailureKind.rejected].
  final RejectionReason? rejection;
}

// Controller ----------------------------------------------------------------

/// Runs one assistant request at a time, from typed (later spoken) text to a
/// reply:
///
/// text → [AIService] → [ActionParser] → [ActionValidator] (dates resolved
/// by [DateResolver]) → [ActionExecutor] → [ResponseComposer].
///
/// The clock is read once per request; the AI context, date resolution and
/// the reply all use that one reading. The controller reads the store only
/// through the validator and never writes to it — [ActionExecutor] is the
/// only writer, and only for a [Ready] result or after [confirm].
class AssistantController extends ChangeNotifier {
  AssistantController({
    required this._store,
    required this._ai,
    Clock? clock,
    ActionExecutor? executor,
  })  : _clock = clock ?? DateTime.now,
        _executor = executor ?? ActionExecutor(_store);

  final AppStore _store;
  final AIService _ai;
  final Clock _clock;
  final ActionExecutor _executor;

  static const _parser = ActionParser();

  AssistantState _state = const AssistantIdle();
  AssistantState get state => _state;

  bool get isBusy => _state is AssistantProcessing;

  bool _disposed = false;

  /// Handles one request. Ignored while another is in flight, or when [text]
  /// is blank.
  Future<void> submit(String text) async {
    final transcript = text.trim();
    if (transcript.isEmpty || isBusy) return;

    final now = _clock();
    _set(AssistantProcessing(transcript));

    final String answer;
    try {
      answer = await _ai.interpret(transcript, AssistantContext(now));
    } on AIServiceException catch (error) {
      if (_disposed) return;
      _fail(transcript, now, _aiMessage(error.failure));
      return;
    } catch (error) {
      // A provider bug must not break the screen; treat it as an outage.
      debugPrint('MONDAY: assistant provider failed: $error');
      if (_disposed) return;
      _fail(transcript, now, _aiMessage(AIFailure.unavailable));
      return;
    }
    if (_disposed) return;

    final composer = ResponseComposer(now);
    final validation = ActionValidator(_store, clock: () => now)
        .validate(_parser.parseJson(answer));

    switch (validation) {
      case Ready(:final action):
        _run(transcript, action, composer);
      case NeedsConfirmation():
        _set(AssistantNeedsConfirmation(
          transcript: transcript,
          action: validation.action,
          reasons: List.unmodifiable(validation.reasons),
          message: composer.confirmation(validation),
          requestedAt: now,
        ));
      case NeedsClarification():
        _set(AssistantNeedsClarification(
          transcript: transcript,
          reason: validation.reason,
          message: composer.clarification(validation),
          timeOptions: List.unmodifiable(validation.timeOptions),
        ));
      case Rejected():
        _set(AssistantFailed(
          transcript: transcript,
          kind: AssistantFailureKind.rejected,
          rejection: validation.reason,
          message: composer.rejection(validation),
          requestedAt: now,
        ));
    }
  }

  /// Runs the action waiting for confirmation, exactly as it was shown.
  void confirm() {
    final state = _state;
    if (state is! AssistantNeedsConfirmation) return;
    _run(state.transcript, state.action, ResponseComposer(state.requestedAt));
  }

  /// Drops the action waiting for confirmation without running it.
  void cancel() {
    if (_state is AssistantNeedsConfirmation) _set(const AssistantIdle());
  }

  /// After a failure, keeps the user's words as an Inbox item instead.
  void saveToInbox() {
    final state = _state;
    if (state is! AssistantFailed) return;
    _run(
      state.transcript,
      ResolvedInboxCapture(state.transcript),
      ResponseComposer(state.requestedAt),
    );
  }

  /// Clears whatever is showing. Has no effect while a request is in flight.
  void reset() {
    if (!isBusy) _set(const AssistantIdle());
  }

  void _run(String transcript, ResolvedAction action, ResponseComposer composer) {
    final ExecutionResult result;
    try {
      result = _executor.execute(action);
    } catch (error) {
      debugPrint('MONDAY: assistant action failed: $error');
      _fail(
        transcript,
        composer.now,
        'Maaf, ada masalah saat menyimpan. Coba lagi.',
        kind: AssistantFailureKind.executionFailed,
      );
      return;
    }
    _set(AssistantSucceeded(
      transcript: transcript,
      result: result,
      message: composer.executed(result),
    ));
  }

  void _fail(
    String transcript,
    DateTime now,
    String message, {
    AssistantFailureKind kind = AssistantFailureKind.aiUnavailable,
  }) {
    _set(AssistantFailed(
      transcript: transcript,
      kind: kind,
      message: message,
      requestedAt: now,
    ));
  }

  static String _aiMessage(AIFailure failure) => switch (failure) {
        AIFailure.offline => 'Tidak ada koneksi internet.',
        AIFailure.timeout => 'Asisten terlalu lama merespons.',
        AIFailure.unavailable => 'Asisten sedang tidak tersedia.',
      };

  void _set(AssistantState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
