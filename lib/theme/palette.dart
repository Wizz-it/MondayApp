import 'package:flutter/material.dart';

/// The MONDAY colour system, sampled from the Figma reference.
///
/// Material's [ColorScheme] does not have slots for everything the design
/// needs (tinted icon tiles, the assistant hero gradient, hairline dividers),
/// so the full palette lives here as a [ThemeExtension] and the colour scheme
/// is derived from it in `app_theme.dart`.
@immutable
class MondayPalette extends ThemeExtension<MondayPalette> {
  const MondayPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.hairline,
    required this.green,
    required this.onGreen,
    required this.accent,
    required this.onAccent,
    required this.tileSage,
    required this.tileLilac,
    required this.onTile,
    required this.heroTop,
    required this.heroBottom,
    required this.heroGlow,
    required this.titleAccent,
    required this.navSelected,
    required this.danger,
  });

  /// Page background.
  final Color canvas;

  /// Cards, sheets, grouped lists.
  final Color surface;

  /// Input fields and other recessed areas inside a [surface].
  final Color surfaceMuted;

  final Color ink;
  final Color inkMuted;

  /// Eyebrow labels and counters.
  final Color inkFaint;

  final Color hairline;

  /// Primary action colour: filled buttons, selected chips, the FAB.
  final Color green;
  final Color onGreen;

  /// The lime highlight: checked boxes, the mic pill, the selected nav item.
  final Color accent;
  final Color onAccent;

  final Color tileSage;
  final Color tileLilac;
  final Color onTile;

  final Color heroTop;
  final Color heroBottom;
  final Color heroGlow;

  /// The coloured full stop after every screen title: "Tasks."
  final Color titleAccent;

  /// Pill behind the selected bottom-navigation icon.
  final Color navSelected;

  final Color danger;

  static const light = MondayPalette(
    canvas: Color(0xFFF7F8F3),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFFAFBF7),
    ink: Color(0xFF132C26),
    inkMuted: Color(0xFF6B7D73),
    inkFaint: Color(0xFF9AA79F),
    hairline: Color(0xFFE4EBE2),
    green: Color(0xFF233F31),
    onGreen: Color(0xFFFFFFFF),
    accent: Color(0xFFD7F1B4),
    onAccent: Color(0xFF233F31),
    tileSage: Color(0xFFE2EFDB),
    tileLilac: Color(0xFFE9E9F3),
    onTile: Color(0xFF233F31),
    heroTop: Color(0xFF132C26),
    heroBottom: Color(0xFF233F33),
    heroGlow: Color(0xFFA8DC7A),
    titleAccent: Color(0xFF87AD73),
    navSelected: Color(0xFFE3F2D5),
    danger: Color(0xFFB3261E),
  );

  static const dark = MondayPalette(
    canvas: Color(0xFF14231D),
    surface: Color(0xFF1C3027),
    surfaceMuted: Color(0xFF192B23),
    ink: Color(0xFFE6F0E6),
    inkMuted: Color(0xFF9BB3A4),
    inkFaint: Color(0xFF7D9488),
    hairline: Color(0xFF355343),
    green: Color(0xFF477150),
    onGreen: Color(0xFFFFFFFF),
    accent: Color(0xFFD7F1B4),
    onAccent: Color(0xFF14231D),
    tileSage: Color(0xFF355343),
    tileLilac: Color(0xFF3A3F55),
    onTile: Color(0xFFB8DCAC),
    heroTop: Color(0xFF1B3A2C),
    heroBottom: Color(0xFF28503C),
    heroGlow: Color(0xFFA8DC7A),
    titleAccent: Color(0xFFA8C99A),
    navSelected: Color(0xFF355343),
    danger: Color(0xFFE48B84),
  );

  @override
  MondayPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? hairline,
    Color? green,
    Color? onGreen,
    Color? accent,
    Color? onAccent,
    Color? tileSage,
    Color? tileLilac,
    Color? onTile,
    Color? heroTop,
    Color? heroBottom,
    Color? heroGlow,
    Color? titleAccent,
    Color? navSelected,
    Color? danger,
  }) {
    return MondayPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      hairline: hairline ?? this.hairline,
      green: green ?? this.green,
      onGreen: onGreen ?? this.onGreen,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      tileSage: tileSage ?? this.tileSage,
      tileLilac: tileLilac ?? this.tileLilac,
      onTile: onTile ?? this.onTile,
      heroTop: heroTop ?? this.heroTop,
      heroBottom: heroBottom ?? this.heroBottom,
      heroGlow: heroGlow ?? this.heroGlow,
      titleAccent: titleAccent ?? this.titleAccent,
      navSelected: navSelected ?? this.navSelected,
      danger: danger ?? this.danger,
    );
  }

  @override
  MondayPalette lerp(ThemeExtension<MondayPalette>? other, double t) {
    if (other is! MondayPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MondayPalette(
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkFaint: c(inkFaint, other.inkFaint),
      hairline: c(hairline, other.hairline),
      green: c(green, other.green),
      onGreen: c(onGreen, other.onGreen),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      tileSage: c(tileSage, other.tileSage),
      tileLilac: c(tileLilac, other.tileLilac),
      onTile: c(onTile, other.onTile),
      heroTop: c(heroTop, other.heroTop),
      heroBottom: c(heroBottom, other.heroBottom),
      heroGlow: c(heroGlow, other.heroGlow),
      titleAccent: c(titleAccent, other.titleAccent),
      navSelected: c(navSelected, other.navSelected),
      danger: c(danger, other.danger),
    );
  }
}

extension MondayPaletteX on BuildContext {
  /// Shorthand for the MONDAY palette of the nearest theme.
  MondayPalette get palette =>
      Theme.of(this).extension<MondayPalette>() ?? MondayPalette.light;
}
