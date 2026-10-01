import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'icon_tile.dart';

/// The dashed-outline empty state: a tinted icon tile, a reassuring headline,
/// a line of guidance and an optional inline action.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: p.hairline,
        radius: MondayRadius.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            IconTile(icon, size: 56, iconSize: 25),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MondayType.rowTitle.copyWith(color: p.ink, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MondayType.rowMeta.copyWith(
                color: p.inkMuted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              Material(
                color: p.tileSage,
                borderRadius: BorderRadius.circular(MondayRadius.tile),
                child: InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(MondayRadius.tile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 17, color: p.onTile),
                        const SizedBox(width: 8),
                        Text(
                          actionLabel!,
                          style: MondayType.rowTitle.copyWith(color: p.onTile),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    const dash = 6.0;
    const gap = 5.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
