import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'design/typography.dart';

export 'design/tokens.dart';
export 'design/typography.dart';

/// Styles de texte Riftarium. Le thème est unique (nuit de Piltover) : les
/// couleurs ne dépendent pas du contexte, gardé en paramètre pour que les
/// écrans continuent d'écrire `riftText(context)`.
RiftTextStyles riftText(BuildContext context) => riftTextStyles;

/// Styles de texte du thème unique.
const riftTextStyles = RiftTextStyles(
  ink: RiftColors.ink,
  muted: RiftColors.muted,
);

/// Thème unique de l'application : nuit de Piltover. Les cartes sont la source
/// de lumière, l'écrin reste sombre — il n'y a donc pas de variante claire.
///
/// Le résultat est mémoïsé : assembler une centaine d'objets à chaque
/// reconstruction serait du gâchis. La clé est la plateforme, parce que
/// `ThemeData` y fige `defaultTargetPlatform` (les widgets adaptatifs le
/// relisent, et les tests le surchargent).
ThemeData buildTheme() =>
    _cache.putIfAbsent(defaultTargetPlatform, _buildTheme);

final _cache = <TargetPlatform, ThemeData>{};

ThemeData _buildTheme() {
  const ink = RiftColors.ink;
  const muted = RiftColors.muted;
  const paper = RiftColors.paper;
  const paper2 = RiftColors.paper2;
  const line = RiftColors.line;
  const text = riftTextStyles;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: RiftColors.gold,
        brightness: Brightness.dark,
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
    brightness: Brightness.dark,
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
      brightness: Brightness.dark,
      primaryColor: RiftColors.gold,
      scaffoldBackgroundColor: paper,
      barBackgroundColor: paper2.withValues(alpha: 0.92),
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
