import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// The dark assistant card on Home: a deep green panel with a glowing orb,
/// concentric rings, and the entry points into "Talk to MONDAY".
class AssistantHeroCard extends StatelessWidget {
  const AssistantHeroCard({super.key, required this.onTap, this.onMicTap});

  final VoidCallback onTap;
  final VoidCallback? onMicTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      color: p.heroTop,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 212,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.heroTop, p.heroBottom],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _OrbPainter(glow: p.heroGlow)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 9),
                          decoration: BoxDecoration(
                            color: p.heroGlow,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'YOUR PERSONAL ASSISTANT',
                            style: MondayType.eyebrow.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ),
                        _OutlineArrow(onTap: onTap),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Anything on your mind?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Talk it through with MONDAY.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _MicPill(onTap: onMicTap ?? onTap, palette: p),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineArrow extends StatelessWidget {
  const _OutlineArrow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
      ),
    );
  }
}

class _MicPill extends StatelessWidget {
  const _MicPill({required this.onTap, required this.palette});

  final VoidCallback onTap;
  final MondayPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.accent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.mic_none, size: 21, color: palette.onAccent),
        ),
      ),
    );
  }
}

/// The glowing orb and its concentric rings.
class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.glow});

  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.45, size.height * 0.42);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = glow.withValues(alpha: 0.14);
    for (final r in [58.0, 92.0, 128.0]) {
      canvas.drawCircle(center, r, ringPaint);
    }

    final glowRect = Rect.fromCircle(center: center, radius: 62);
    canvas.drawCircle(
      center,
      62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.95),
            glow.withValues(alpha: 0.45),
            glow.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(glowRect),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.glow != glow;
}
