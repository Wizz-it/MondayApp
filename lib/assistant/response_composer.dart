import '../utils/date_labels.dart';
import 'action_executor.dart';
import 'action_validator.dart';
import 'agenda_query.dart';
import 'date_resolver.dart';

/// Short Indonesian replies built from templates — no model involved.
///
/// Dates are written "4 Oktober" (with the year only when it is not this
/// year) and times "07.00", matching how the app shows times elsewhere.
class ResponseComposer {
  const ResponseComposer(this.now);

  /// The same reading of the clock the request was validated with, so
  /// "Hari ini" and "Besok" agree with the dates that were resolved.
  final DateTime now;

  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  // Executed actions --------------------------------------------------------

  String executed(ExecutionResult result) {
    switch (result) {
      case TaskCreated():
        final text = StringBuffer('Task ${result.title} ditambahkan');
        if (result.projectName != null) {
          text.write(' ke proyek ${result.projectName}');
        } else if (result.unmatchedProject != null) {
          // The user has already agreed to this when confirming.
          text.write(' tanpa proyek');
        }
        if (result.dueDate != null) {
          text.write(' untuk ${_date(result.dueDate!)}');
        }
        if (result.reminder != null) {
          text.write(', dengan pengingat pukul ${dottedTime(result.reminder!)}');
        }
        text.write('.');
        return text.toString();

      case EventCreated(:final title, :final start):
        return 'Event $title dijadwalkan pada ${_date(start)} '
            'pukul ${dottedTime(start)}.';

      case NoteCreated(:final title):
        return 'Catatan $title disimpan.';

      case InboxCaptured():
        return 'Sudah dicatat ke Inbox.';

      case AgendaAnswered(:final agenda):
        return _agenda(agenda);
    }
  }

  String _agenda(AgendaSnapshot agenda) {
    final when = _dayPhrase(agenda.day);
    final tasks = agenda.openTasks.length;
    final events = agenda.events.length;

    final summary = switch ((agenda.includesTasks, agenda.includesEvents)) {
      (true, true) when tasks == 0 && events == 0 =>
        '$when tidak ada task atau event.',
      (true, true) when events == 0 =>
        '$when ada $tasks task dan tidak ada event.',
      (true, true) when tasks == 0 =>
        '$when tidak ada task dan ada $events event.',
      (true, true) => '$when ada $tasks task dan $events event.',
      (true, false) =>
        tasks == 0 ? '$when tidak ada task.' : '$when ada $tasks task.',
      _ => events == 0 ? '$when tidak ada event.' : '$when ada $events event.',
    };

    final details = [
      summary,
      if (tasks > 0)
        'Task: ${agenda.openTasks.map((t) => t.title).join(', ')}.',
      if (events > 0)
        'Event: ${agenda.events.map(
              (e) => '${e.title} pukul ${dottedTime(e.start)}',
            ).join(', ')}.',
      if (agenda.includesTasks && agenda.completedTaskCount > 0)
        '${agenda.completedTaskCount} task sudah selesai.',
    ];
    return details.join(' ');
  }

  // Outcomes that did not execute -------------------------------------------

  /// One question covering every reason, so the user answers once.
  String confirmation(NeedsConfirmation result) {
    final action = result.action;
    final parts = <String>[];
    for (final reason in result.reasons) {
      switch (reason) {
        case ConfirmationReason.unknownProject:
          final name = (action as ResolvedTask).unmatchedProject;
          parts.add('Proyek $name tidak ditemukan.');
        case ConfirmationReason.pastTime:
          final when = _when(action)!;
          parts.add('Waktunya sudah lewat (${_date(when)} pukul '
              '${dottedTime(when)}).');
        case ConfirmationReason.pastDay:
          parts.add('Tanggal ${_date(_day(action)!)} sudah lewat.');
      }
    }
    parts.add(result.reasons.contains(ConfirmationReason.unknownProject)
        ? 'Simpan task ${(action as ResolvedTask).title} tanpa proyek?'
        : 'Tetap disimpan?');
    return parts.join(' ');
  }

  String clarification(NeedsClarification result) {
    switch (result.reason) {
      case ClarificationReason.askedByAssistant:
        final question = result.question?.trim() ?? '';
        return question.isEmpty ? 'Bisa dijelaskan lagi?' : question;
      case ClarificationReason.missingEventDate:
        return 'Event-nya hari apa?';
      case ClarificationReason.missingEventTime:
        return 'Jam berapa?';
      case ClarificationReason.ambiguousTime:
        final times = [for (final t in result.timeOptions) _clock(t)];
        return times.length < 2
            ? 'Jam berapa tepatnya?'
            : 'Maksudnya pukul ${times.join(' atau ')}?';
      case ClarificationReason.unclearTime:
        return 'Jam berapa tepatnya?';
    }
  }

  String rejection(Rejected result) {
    return switch (result.reason) {
      RejectionReason.emptyTitle => 'Judulnya kosong, jadi belum bisa disimpan.',
      RejectionReason.emptyText => 'Tidak ada yang bisa dicatat.',
      RejectionReason.invalidDate => 'Tanggalnya tidak valid.',
      RejectionReason.invalidTime => 'Jamnya tidak valid.',
      RejectionReason.destructive =>
        'Maaf, aku belum bisa mengubah, menyelesaikan, atau menghapus data.',
      RejectionReason.notSupportedYet =>
        'Maaf, aku belum bisa membantu dengan itu.',
      RejectionReason.outOfScope => 'Maaf, permintaan itu belum bisa aku bantu.',
      RejectionReason.notUnderstood => 'Maaf, aku belum mengerti permintaan itu.',
    };
  }

  // Formatting --------------------------------------------------------------

  /// "4 Oktober", or "4 Januari 2027" outside the current year.
  String _date(DateTime date) {
    final month = _months[date.month - 1];
    return date.year == now.year
        ? '${date.day} $month'
        : '${date.day} $month ${date.year}';
  }

  /// "Hari ini", "Besok", "Lusa" or "Pada 6 Oktober".
  String _dayPhrase(DateTime day) {
    // Compared as UTC calendar dates, so a daylight-saving change between the
    // two days can't make a whole day come out as 23 hours.
    final days = DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
    return switch (days) {
      0 => 'Hari ini',
      1 => 'Besok',
      2 => 'Lusa',
      _ => 'Pada ${_date(day)}',
    };
  }

  /// "07.00", as [dottedTime] writes it.
  static String _clock(ClockTime time) =>
      dottedTime(DateTime(2000, 1, 1, time.hour, time.minute));

  /// The moment a candidate is about, for confirmation questions.
  static DateTime? _when(ResolvedAction action) => switch (action) {
        ResolvedTask(:final reminder) => reminder,
        ResolvedEvent(:final start) => start,
        _ => null,
      };

  static DateTime? _day(ResolvedAction action) => switch (action) {
        ResolvedTask(:final dueDate) => dueDate,
        ResolvedEvent(:final start) => dayOf(start),
        _ => null,
      };
}
