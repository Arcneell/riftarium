import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'design/typography.dart';

export 'design/tokens.dart';
export 'design/typography.dart';

/// Compatibilité : anciens noms utilisés dans les écrans de la phase 1.
const Color kRiftariumGold = RiftColors.gold;
const Color kRiftariumParchment = RiftColors.paper;
const Color kRiftariumInk = RiftColors.ink;

/// Styles de texte Riftarium pour le thème courant.
RiftTextStyles riftText(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return RiftTextStyles(
    ink: dark ? RiftColors.darkInk : RiftColors.ink,
    muted: dark ? RiftColors.darkMuted : RiftColors.muted,
  );
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? RiftColors.darkInk : RiftColors.ink;
  final muted = dark ? RiftColors.darkMuted : RiftColors.muted;
  final paper = dark ? RiftColors.darkPaper : RiftColors.paper;
  final paper2 = dark ? RiftColors.darkPaper2 : RiftColors.paper2;
  final line = dark ? RiftColors.darkLine : RiftColors.line;
  final text = RiftTextStyles(ink: ink, muted: muted);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: RiftColors.gold,
        brightness: brightness,
      ).copyWith(
        primary: RiftColors.gold,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF2C2410),
        onPrimaryContainer: RiftColors.goldSoft,
        secondary: RiftColors.hex,
        onSecondary: Colors.white,
        secondaryContainer: RiftColors.hexSoft,
        onSecondaryContainer: RiftColors.calmText,
        surface: paper,
        onSurface: ink,
        surfaceContainerHighest: paper2,
        surfaceContainerHigh: paper2,
        surfaceContainer: paper2,
        onSurfaceVariant: muted,
        outline: line,
        outlineVariant: line,
        error: RiftColors.fury,
      );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    fontFamily: RiftFonts.body,
    scaffoldBackgroundColor: paper,
    canvasColor: paper,
    dividerColor: line,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(fontFamily: RiftFonts.body, bodyColor: ink, displayColor: ink)
        .copyWith(
          displayLarge: text.displayLarge,
          displayMedium: text.displayMedium,
          displaySmall: text.displaySmall,
          headlineLarge: text.displayMedium,
          headlineMedium: text.displaySmall,
          headlineSmall: text.displaySmall.copyWith(fontSize: 18),
          titleLarge: text.title.copyWith(fontSize: 19),
          titleMedium: text.title,
          titleSmall: text.title.copyWith(fontSize: 15),
          bodyLarge: text.body.copyWith(fontSize: 16.5),
          bodyMedium: text.body,
          bodySmall: text.small,
          labelLarge: text.bodyStrong.copyWith(fontSize: 15),
          labelMedium: text.mono,
          labelSmall: text.eyebrow,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.displaySmall,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: RiftColors.paper2.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      indicatorColor: RiftColors.gold.withValues(alpha: 0.18),
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.small.copyWith(
          fontSize: 11.5,
          fontVariations: RiftFonts.weight(
            states.contains(WidgetState.selected) ? 600 : 500,
          ),
          color: states.contains(WidgetState.selected)
              ? RiftColors.goldDeep
              : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? RiftColors.goldDeep
              : muted,
          size: 24,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: RiftColors.paper2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RiftRadius.md),
        side: BorderSide(color: line),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: RiftColors.gold.withValues(alpha: 0.16),
      side: BorderSide(color: line),
      shape: const StadiumBorder(),
      labelStyle: text.small.copyWith(color: ink),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RiftColors.surfaceSolid,
      hintStyle: text.small,
      labelStyle: text.small,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        borderSide: const BorderSide(color: RiftColors.hex, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RiftColors.gold,
        foregroundColor: const Color(0xFF241A06),
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
        textStyle: text.bodyStrong.copyWith(fontSize: 15.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: RiftColors.lineStrong),
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: text.bodyStrong.copyWith(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RiftColors.calmText,
        textStyle: text.bodyStrong.copyWith(fontSize: 15),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: RiftColors.gold.withValues(alpha: 0.18),
        selectedForegroundColor: RiftColors.goldSoft,
        foregroundColor: muted,
        side: BorderSide(color: line),
        textStyle: text.small.copyWith(fontVariations: RiftFonts.weight(600)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RiftRadius.lg),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RiftRadius.md),
      ),
      titleTextStyle: text.displaySmall,
      contentTextStyle: text.body,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: ink,
      titleTextStyle: text.body,
      subtitleTextStyle: text.small,
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: RiftColors.gold,
    ),
    // Les widgets Cupertino rendus dans la MaterialApp héritent de ce thème.
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: RiftColors.gold,
      scaffoldBackgroundColor: paper,
      barBackgroundColor: RiftColors.paper2.withValues(alpha: 0.92),
      textTheme: CupertinoTextThemeData(
        primaryColor: RiftColors.gold,
        textStyle: text.body,
        navTitleTextStyle: text.displaySmall.copyWith(fontSize: 18),
        navLargeTitleTextStyle: text.displayMedium,
        tabLabelTextStyle: text.small.copyWith(fontSize: 10.5),
        actionTextStyle: text.bodyStrong.copyWith(color: RiftColors.calmText),
      ),
    ),
  );
}
