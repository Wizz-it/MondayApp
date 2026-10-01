import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// The All / Today / Upcoming / Done selector on the Tasks screen.
/// Selected chips fill with deep green; the rest are outlined pills.
class MondayFilterChips<T> extends StatelessWidget {
  const MondayFilterChips({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in values) ...[
            _Chip(
              label: labelOf(value),
              selected: value == selected,
              onTap: () => onSelected(value),
              palette: p,
            ),
            if (value != values.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final MondayPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? palette.green : palette.surface,
      borderRadius: BorderRadius.circular(MondayRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MondayRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MondayRadius.pill),
            border: Border.all(
              color: selected ? palette.green : palette.hairline,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: MondayType.rowTitle.copyWith(
              color: selected ? palette.onGreen : palette.ink,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
