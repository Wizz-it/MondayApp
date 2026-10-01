import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The two icon-tile tints used throughout the design.
enum TileTint {
  sage,
  lilac;

  Color background(MondayPalette p) =>
      this == TileTint.sage ? p.tileSage : p.tileLilac;
}
