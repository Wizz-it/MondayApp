import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

class MondayNavItem {
  const MondayNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bottom navigation matching the reference: a compact tinted pill sits behind
/// the selected icon only, with the label underneath.
class MondayBottomNav extends StatelessWidget {
  const MondayBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<MondayNavItem> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.hairline, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MondayNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? p.navSelected : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 21,
                color: selected ? p.green : p.inkMuted,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.label,
              style: MondayType.rowMeta.copyWith(
                fontSize: 11.5,
                color: selected ? p.ink : p.inkMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
