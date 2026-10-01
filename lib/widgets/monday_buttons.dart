import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// The floating rounded-square back control that replaces the app bar on
/// every sub-screen.
class MondayBackButton extends StatelessWidget {
  const MondayBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(MondayRadius.tile),
        elevation: 0,
        child: InkWell(
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(MondayRadius.tile),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.arrow_back, size: 19, color: p.ink),
          ),
        ),
      ),
    );
  }
}

/// Dark-green rounded-square floating action button.
class MondayFab extends StatelessWidget {
  const MondayFab({super.key, required this.onPressed, this.icon = Icons.add});

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.green,
      borderRadius: BorderRadius.circular(MondayRadius.fab),
      elevation: 6,
      shadowColor: p.ink.withValues(alpha: 0.28),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MondayRadius.fab),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(icon, color: p.onGreen, size: 26),
        ),
      ),
    );
  }
}

/// Full-width filled call to action with a trailing arrow — the button that
/// closes every creation sheet.
class MondayPrimaryButton extends StatelessWidget {
  const MondayPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: p.green,
        borderRadius: BorderRadius.circular(MondayRadius.tile),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MondayRadius.tile),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: MondayType.button.copyWith(color: p.onGreen),
                  ),
                ),
                if (showArrow)
                  Icon(Icons.arrow_forward, size: 19, color: p.onGreen),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular icon button used for the sheet close control and the
/// calendar's month arrows.
class MondayCircleButton extends StatelessWidget {
  const MondayCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.background,
    this.foreground,
    this.size = 36,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: background ?? p.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: foreground ?? p.inkMuted),
        ),
      ),
    );
  }
}
