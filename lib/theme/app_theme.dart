import 'package:flutter/material.dart';

import 'palette.dart';

/// Shared type ramp. The reference uses a geometric display sans; until a font
/// is bundled we lean on the platform face and reproduce the design's feel
/// through size, weight and tracking instead.
abstract final class MondayType {
  /// Screen titles: "Tasks.", "Inbox.", "More."
  static const display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.04,
    letterSpacing: -1.4,
  );

  /// The greeting on Home, which runs to two lines.
  static const displaySoft = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.12,
    letterSpacing: -1.1,
  );

  /// "Today's focus", "On your calendar".
  static const section = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  /// Bottom-sheet titles.
  static const sheetTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
  );

  /// List row titles.
  static const rowTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.1,
  );

  /// Row metadata: "MONDAY  •  Today".
  static const rowMeta = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Uppercase, widely tracked labels: "YOUR WORKSPACE", "CAPTURED".
  static const eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
  );

  /// Field labels inside sheets.
  static const fieldLabel = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const button = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
}

/// Corner radii used across the design.
abstract final class MondayRadius {
  static const card = 18.0;
  static const tile = 14.0;
  static const sheet = 28.0;
  static const field = 12.0;
  static const fab = 18.0;
  static const pill = 999.0;
}

/// Horizontal page inset. Every screen uses the same gutter.
const kMondayGutter = 20.0;

ThemeData buildMondayTheme(MondayPalette p, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.green,
    onPrimary: p.onGreen,
    primaryContainer: p.accent,
    onPrimaryContainer: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    surface: p.surface,
    onSurface: p.ink,
    surfaceContainerHighest: p.surfaceMuted,
    onSurfaceVariant: p.inkMuted,
    outline: p.hairline,
    outlineVariant: p.hairline,
    error: p.danger,
    onError: Colors.white,
  );

  final textTheme = TextTheme(
    displayLarge: MondayType.display.copyWith(color: p.ink),
    displayMedium: MondayType.displaySoft.copyWith(color: p.ink),
    headlineSmall: MondayType.section.copyWith(color: p.ink),
    titleLarge: MondayType.sheetTitle.copyWith(color: p.ink),
    titleMedium: MondayType.rowTitle.copyWith(color: p.ink),
    bodyLarge: MondayType.body.copyWith(color: p.ink),
    bodyMedium: MondayType.body.copyWith(color: p.inkMuted),
    bodySmall: MondayType.rowMeta.copyWith(color: p.inkMuted),
    labelSmall: MondayType.eyebrow.copyWith(color: p.inkFaint),
    labelLarge: MondayType.button,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.canvas,
    canvasColor: p.canvas,
    textTheme: textTheme,
    dividerTheme: DividerThemeData(
      color: p.hairline,
      thickness: 1,
      space: 1,
    ),
    splashFactory: InkSparkle.splashFactory,
    extensions: [p],
    // The design has no app bars; sub-screens use a floating back button.
    appBarTheme: AppBarTheme(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: p.ink,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: p.heroTop.withValues(alpha: 0.42),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MondayRadius.sheet),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.green,
        foregroundColor: p.onGreen,
        minimumSize: const Size.fromHeight(56),
        textStyle: MondayType.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MondayRadius.tile),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.green,
      contentTextStyle: MondayType.rowTitle.copyWith(color: p.onGreen),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MondayRadius.tile),
      ),
    ),
  );
}

ThemeData get mondayLightTheme =>
    buildMondayTheme(MondayPalette.light, Brightness.light);

ThemeData get mondayDarkTheme =>
    buildMondayTheme(MondayPalette.dark, Brightness.dark);
