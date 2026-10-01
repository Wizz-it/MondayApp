import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../utils/date_labels.dart';

/// The small day block used beside calendar entries on Home: a big day number
/// above a short month label.
class DateTile extends StatelessWidget {
  const DateTile(this.date, {super.key, this.background});

  final DateTime date;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background ?? p.tileSage,
        borderRadius: BorderRadius.circular(MondayRadius.tile),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: MondayType.rowTitle.copyWith(
              color: p.onTile,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            monthShort(date.month).toUpperCase(),
            style: MondayType.eyebrow.copyWith(
              color: p.onTile.withValues(alpha: 0.75),
              fontSize: 8.5,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
