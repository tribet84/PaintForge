import 'package:flutter/material.dart';

/// Stock status colours.
///
/// Kept OUT of the seeded ColorScheme on purpose: those roles already mean
/// something (primary is the brand, error is a failure), and reusing them
/// made a healthy shelf render in brand-brown and a nearly-empty pot in
/// alarm-red. Status needs its own good / warning / absent scale, readable
/// in both themes.
class StockColors {
  const StockColors._();

  static Color inStock(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF7FC98A) : const Color(0xFF3E8E4E);

  // Light amber is 0xFF8F5A00, not the prettier 0xFFB77410 it used to be:
  // that one measured 3.8:1 against white, below the 4.5:1 the coloured
  // status words need at body-text size.
  static Color low(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFE8B45C) : const Color(0xFF8F5A00);

  static Color missing(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF6E6157) : const Color(0xFFC9BDB3);

  static Color of(BuildContext context, Color Function(Brightness) role) =>
      role(Theme.of(context).brightness);
}

/// PintaMinis look & feel: forge orange over dark steel.
class PintaMinisTheme {
  static const seed = Color(0xFFE8590C);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
