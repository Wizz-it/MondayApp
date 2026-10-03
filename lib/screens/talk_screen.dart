import 'package:flutter/material.dart';

import '../assistant/assistant_controller.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/grouped_card.dart';
import '../widgets/monday_buttons.dart';
import '../widgets/screen_header.dart';

/// The central assistant surface.
///
/// Voice capture is not wired up yet, so the screen presents the reference's
/// typed fallback: tapping the mic explains that speech is unavailable and
/// hands over to the text field.
///
/// Without an [assistant] the text field saves straight to the inbox, as it
/// always has. With one, the text goes to the assistant and its reply —
/// including questions, confirmations and a save-to-inbox fallback — shows
/// under the mic.
class TalkScreen extends StatefulWidget {
  const TalkScreen({super.key, this.assistant});

  /// Owned by the caller, which also disposes it.
  final AssistantController? assistant;

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _micAttempted = false;

  @override
  void dispose() {
    _pulse.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onMicTap() {
    setState(() => _micAttempted = true);
    _focus.requestFocus();
  }

  void _submit() {
    final text = _input.text.trim();
    final assistant = widget.assistant;
    if (text.isEmpty || (assistant?.isBusy ?? false)) return;

    if (assistant != null) {
      assistant.submit(text);
    } else {
      AppScope.read(context).captureThought(text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your inbox.')),
      );
    }
    _input.clear();
    _focus.unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kMondayGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const MondayBackButton(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          size: const Size(260, 220),
                          painter: _OrbPainter(
                            glow: p.heroGlow,
                            core: p.green,
                            t: _pulse.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const EyebrowLabel(
                        'A MOMENT OF CLARITY',
                        leadingRule: true,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "What's on\nyour mind?",
                        textAlign: TextAlign.center,
                        style: MondayType.display.copyWith(
                          color: p.ink,
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Capture a thought or speak it out loud. MONDAY will '
                        'keep it safe in your inbox.',
                        textAlign: TextAlign.center,
                        style: MondayType.body.copyWith(
                          color: p.inkMuted,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _MicButton(onTap: _onMicTap),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to speak',
                        style: MondayType.rowTitle.copyWith(
                          color: p.ink,
                          fontSize: 13.5,
                        ),
                      ),
                      if (_micAttempted) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Voice input is not available yet. You can type '
                          'below instead.',
                          textAlign: TextAlign.center,
                          style: MondayType.rowMeta.copyWith(
                            color: p.inkMuted,
                          ),
                        ),
                      ],
                      if (widget.assistant case final assistant?)
                        ListenableBuilder(
                          listenable: assistant,
                          builder: (context, _) => _AssistantReply(assistant),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ListenableBuilder(
                  listenable: widget.assistant ?? const _NeverChanges(),
                  builder: (context, _) => _TypeField(
                    controller: _input,
                    focusNode: _focus,
                    enabled: !(widget.assistant?.isBusy ?? false),
                    onChanged: (_) => setState(() {}),
                    onSubmit: _submit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Material(
        color: p.green,
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: p.green.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 66,
            height: 66,
            child: Icon(Icons.mic_none, size: 27, color: p.onGreen),
          ),
        ),
      ),
    );
  }
}

/// The assistant's reply to the latest request, under the mic.
class _AssistantReply extends StatelessWidget {
  const _AssistantReply(this.assistant);

  final AssistantController assistant;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final body = MondayType.body.copyWith(color: p.ink, fontSize: 14);

    final (transcript, content) = switch (assistant.state) {
      AssistantIdle() => (null, null),
      AssistantProcessing(:final transcript) => (
          transcript,
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: p.green,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'MONDAY sedang memproses...',
                style: body.copyWith(color: p.inkMuted),
              ),
            ],
          ),
        ),
      AssistantSucceeded(:final transcript, :final message) ||
      AssistantNeedsClarification(:final transcript, :final message) =>
        (transcript, Text(message, style: body)),
      final AssistantNeedsConfirmation state => (
          state.transcript,
          _withActions(Text(state.message, style: body), [
            _ReplyAction(
              label: state.withoutProject
                  ? 'Simpan tanpa proyek'
                  : 'Tetap simpan',
              primary: true,
              onTap: assistant.confirm,
            ),
            _ReplyAction(label: 'Batal', onTap: assistant.cancel),
          ]),
        ),
      AssistantFailed(:final transcript, :final message) => (
          transcript,
          _withActions(Text(message, style: body), [
            _ReplyAction(
              label: 'Simpan ke Inbox',
              primary: true,
              onTap: assistant.saveToInbox,
            ),
          ]),
        ),
    };
    if (transcript == null || content == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '"$transcript"',
              style: MondayType.rowMeta.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: 10),
            content,
          ],
        ),
      ),
    );
  }

  static Widget _withActions(Widget message, List<Widget> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        message,
        const SizedBox(height: 8),
        Wrap(spacing: 4, children: actions),
      ],
    );
  }
}

class _ReplyAction extends StatelessWidget {
  const _ReplyAction({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      child: Text(
        label,
        style: MondayType.rowTitle.copyWith(
          color: primary ? p.green : p.inkMuted,
        ),
      ),
    );
  }
}

/// Stands in for an absent assistant so the text field can always listen.
class _NeverChanges implements Listenable {
  const _NeverChanges();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _TypeField extends StatelessWidget {
  const _TypeField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  /// False while the assistant is working on the previous request.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasText = enabled && controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(MondayRadius.pill),
        border: Border.all(color: p.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
              textInputAction: TextInputAction.send,
              cursorColor: p.green,
              style: MondayType.body.copyWith(color: p.ink, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: "Or type what's on your mind...",
                hintStyle: MondayType.body.copyWith(
                  color: p.inkFaint,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: hasText ? p.green : p.tileSage,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: hasText ? onSubmit : null,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: hasText ? p.onGreen : p.onTile,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The large breathing orb at the top of the Talk screen.
class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.glow, required this.core, required this.t});

  final Color glow;
  final Color core;

  /// Animation position, 0..1, driving a slow expansion of the rings.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final breathe = 1 + (t * 0.06);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (i, r) in [66.0, 94.0, 122.0].indexed) {
      ringPaint.color = glow.withValues(alpha: 0.26 - i * 0.07);
      canvas.drawCircle(center, r * breathe, ringPaint);
    }

    // Two small satellite dots, as in the reference.
    final dot = Paint()..color = glow.withValues(alpha: 0.9);
    canvas.drawCircle(center + Offset(62, -58) * breathe, 3.5, dot);
    canvas.drawCircle(center + Offset(-86, 30) * breathe, 3, dot);

    final radius = 48.0 * breathe;
    canvas.drawCircle(
      center,
      radius * 1.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.35),
            glow.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5)),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.topLeft,
          radius: 1.2,
          colors: [glow, core],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // The waveform glyph inside the orb.
    final bar = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (final (i, h) in [9.0, 15.0, 7.0].indexed) {
      final dx = center.dx + (i - 1) * 9;
      canvas.drawLine(
        Offset(dx, center.dy - h),
        Offset(dx, center.dy + h),
        bar,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t || old.glow != glow || old.core != core;
}
