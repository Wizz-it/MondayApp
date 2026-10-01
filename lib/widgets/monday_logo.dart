import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// The five-dot MONDAY mark. Drawn rather than bundled so the app still has no
/// asset dependencies; swap in the real artwork when it is exported.
class MondayMark extends StatelessWidget {
  const MondayMark({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(color: color ?? context.palette.ink),
    );
  }
}

/// The mark alongside the "MONDAY." wordmark, as shown in the Home header.
class MondayWordmark extends StatelessWidget {
  const MondayWordmark({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ink = color ?? p.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MondayMark(size: 20, color: ink),
        const SizedBox(width: 9),
        Text.rich(
          TextSpan(
            text: 'MONDAY',
            style: TextStyle(
              color: ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
            children: [
              TextSpan(
                text: '.',
                style: MondayType.rowTitle.copyWith(
                  color: p.titleAccent,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.color});

  final Color color;

  /// Relative dot positions and radii, scaled to the painted box.
  static const _dots = <({double x, double y, double r})>[
    (x: 0.10, y: 0.30, r: 0.085),
    (x: 0.40, y: 0.12, r: 0.105),
    (x: 0.72, y: 0.34, r: 0.080),
    (x: 0.26, y: 0.66, r: 0.075),
    (x: 0.60, y: 0.78, r: 0.095),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final d in _dots) {
      canvas.drawCircle(
        Offset(size.width * d.x, size.height * d.y),
        size.shortestSide * d.r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
