import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The two icon-tile tints used throughout the design.
enum TileTint {
  sage('Sage'),
  lilac('Lilac');

  const TileTint(this.label);
  final String label;

  Color background(MondayPalette p) =>
      this == TileTint.sage ? p.tileSage : p.tileLilac;
}
