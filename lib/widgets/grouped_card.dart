import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// The design groups related rows into a single rounded surface with hairline
/// dividers between them, rather than stacking separate cards.
class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: p.hairline));
      }
      rows.add(children[i]);
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(MondayRadius.card),
        boxShadow: [
          BoxShadow(
            color: p.ink.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// A standalone rounded surface — used for the note editor, the project tile
/// list and anywhere a single card is wanted without dividers.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(MondayRadius.card),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A single row inside a [GroupedCard]: optional leading widget, title,
/// optional metadata line, optional trailing widget.
class MondayRow extends StatelessWidget {
  const MondayRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleStyle,
    this.subtitleStyle,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DefaultTextStyle.merge(
                      style: titleStyle ??
                          MondayType.rowTitle.copyWith(color: p.ink),
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle.merge(
                        style: subtitleStyle ??
                            MondayType.rowMeta.copyWith(color: p.inkMuted),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The chevron that ends most tappable rows.
class RowChevron extends StatelessWidget {
  const RowChevron({super.key});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right, size: 20, color: context.palette.inkFaint);
}

/// The forward arrow used on project rows.
class RowArrow extends StatelessWidget {
  const RowArrow({super.key});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.arrow_forward, size: 18, color: context.palette.inkMuted);
}
