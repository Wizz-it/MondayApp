import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// Uppercase, widely tracked label: "YOUR WORKSPACE", "MONDAY / TASKS".
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel(this.text, {super.key, this.color, this.leadingRule = false});

  final String text;
  final Color? color;

  /// Draws the short horizontal rule the Home and Talk screens put before
  /// their eyebrow.
  final bool leadingRule;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = Text(
      text.toUpperCase(),
      style: MondayType.eyebrow.copyWith(color: color ?? p.inkFaint),
    );

    if (!leadingRule) return label;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 1.4,
          margin: const EdgeInsets.only(right: 10),
          color: color ?? p.inkFaint,
        ),
        label,
      ],
    );
  }
}

/// A screen title with the design's signature coloured full stop.
class DisplayTitle extends StatelessWidget {
  const DisplayTitle(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = (style ?? MondayType.display).copyWith(color: p.ink);
    return Text.rich(
      TextSpan(
        text: text,
        style: base,
        children: [
          TextSpan(text: '.', style: base.copyWith(color: p.titleAccent)),
        ],
      ),
    );
  }
}

/// The eyebrow + title + subtitle block that opens every screen.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.leadingRule = false,
    this.titleStyle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool leadingRule;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EyebrowLabel(eyebrow, leadingRule: leadingRule),
        const SizedBox(height: 14),
        DisplayTitle(title, style: titleStyle),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!, style: MondayType.body.copyWith(color: p.inkMuted)),
        ],
      ],
    );
  }
}

/// "Today's focus" with an optional trailing link such as "View tasks →".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text(title, style: MondayType.section.copyWith(color: p.ink)),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: MondayType.rowMeta.copyWith(
                      color: p.inkMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 15, color: p.inkMuted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// An eyebrow with a counter on the far right: "YOUR TASKS" … "03".
class EyebrowRow extends StatelessWidget {
  const EyebrowRow({super.key, required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(child: EyebrowLabel(label)),
        if (trailing != null)
          Text(
            trailing!,
            style: MondayType.eyebrow.copyWith(color: p.inkFaint),
          ),
      ],
    );
  }
}
