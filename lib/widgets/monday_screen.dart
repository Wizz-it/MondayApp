import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'monday_buttons.dart';

/// Shared page shell. The design has no app bars: content scrolls from the top
/// of the safe area, and sub-screens carry an inline back control instead.
class MondayScreen extends StatelessWidget {
  const MondayScreen({
    super.key,
    required this.children,
    this.showBack = false,
    this.fab,
    this.headerAction,
    this.bottomPadding = 40,
  });

  final List<Widget> children;
  final bool showBack;
  final Widget? fab;

  /// Optional control shown opposite the back button, for screen-level
  /// actions such as "edit".
  final Widget? headerAction;

  /// Raised by callers that sit above the bottom navigation bar.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.canvas,
      floatingActionButton: fab,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            kMondayGutter,
            12,
            kMondayGutter,
            bottomPadding,
          ),
          children: [
            if (showBack) ...[
              Row(
                children: [
                  const MondayBackButton(),
                  const Spacer(),
                  ?headerAction,
                ],
              ),
              const SizedBox(height: 44),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}
