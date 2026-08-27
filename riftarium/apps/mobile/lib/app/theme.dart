import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Charte reprise du site (`apps/web/src/style.css`).
const Color kRiftariumGold = Color(0xFFB08A3E);
const Color kRiftariumParchment = Color(0xFFF5EFE1);
const Color kRiftariumInk = Color(0xFF2A2419);

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: kRiftariumGold,
    brightness: brightness,
    surface: light ? kRiftariumParchment : null,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    // Les widgets Cupertino rendus dans une MaterialApp héritent de ce thème.
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: kRiftariumGold,
      scaffoldBackgroundColor: light
          ? kRiftariumParchment
          : CupertinoColors.black,
      barBackgroundColor: light
          ? kRiftariumParchment.withValues(alpha: 0.9)
          : CupertinoColors.darkBackgroundGray,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
