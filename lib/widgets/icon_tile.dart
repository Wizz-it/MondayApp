import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// The tinted rounded square that carries an outline icon in list rows,
/// empty states and the Settings screen.
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.background,
    this.foreground,
    this.size = 46,
    this.iconSize = 21,
  });

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? p.tileSage,
        borderRadius: BorderRadius.circular(MondayRadius.tile),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: foreground ?? p.onTile),
    );
  }
}
