// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';

/// Material 3 themes and the user-selectable accent palette.
class AppTheme {
  AppTheme._();

  static const Color defaultAccent = Color(0xFFB08968);

  static const Map<String, Color> accentColors = {
    'Violet': Color(0xFF6750A4),
    'Red': Color(0xFFB3261E),
    'Amber': Color(0xFF985900),
    'Cocoa': defaultAccent,
    'Green': Color(0xFF2E6B4F),
    'Teal': Color(0xFF007C83),
    'Blue': Color(0xFF1565C0),
    'Orchid': Color(0xFF80509A),
  };

  static ThemeData light({
    Color seedColor = defaultAccent,
    ColorScheme? dynamicScheme,
    bool showNavigationLabels = true,
  }) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        );
    return _build(
      scheme,
      Brightness.light,
      showNavigationLabels: showNavigationLabels,
    );
  }

  static ThemeData dark({
    Color seedColor = defaultAccent,
    ColorScheme? dynamicScheme,
    bool amoledBlack = false,
    bool showNavigationLabels = true,
  }) {
    var scheme = dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);
    if (amoledBlack) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceDim: Colors.black,
        surfaceBright: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: Colors.black,
        surfaceContainer: Colors.black,
        surfaceContainerHigh: Colors.black,
        surfaceContainerHighest: Colors.black,
      );
    }
    return _build(
      scheme,
      Brightness.dark,
      showNavigationLabels: showNavigationLabels,
    );
  }

  static ThemeData _build(
    ColorScheme scheme,
    Brightness brightness, {
    required bool showNavigationLabels,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: showNavigationLabels
            ? NavigationDestinationLabelBehavior.alwaysShow
            : NavigationDestinationLabelBehavior.alwaysHide,
      ),
      textTheme: Typography.englishLike2018.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
