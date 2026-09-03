import 'dart:math' as math;

import '../design/tokens.dart';
import 'card_image.dart';

/// Dimensions d'une grille de cartes : le nombre de colonnes et la taille
/// d'une vignette pour une largeur donnée.
class CardGridMetrics {
  const CardGridMetrics({
    required this.columns,
    required this.tileWidth,
    required this.imageHeight,
  });

  final int columns;

  /// Largeur d'une vignette, gouttières et marges latérales retirées.
  final double tileWidth;

  /// Hauteur du visuel seul (ratio portrait d'une carte), sans le bloc texte.
  final double imageHeight;
}

/// Règle de grille commune à la cartothèque et à la collection : trois colonnes
/// sur un téléphone tenu droit, deux sur un très petit écran, quatre dès qu'on
/// tourne l'appareil (ou sur tablette).
///
/// Fonction pure : `width` est l'étendue transversale du sliver, `gap` la
/// gouttière entre deux colonnes et `padding` la somme des marges latérales.
CardGridMetrics cardGridMetrics({
  required double width,
  required double gap,
  double? padding,
}) {
  final columns = width < 340
      ? 2
      : width >= 640
      ? 4
      : 3;
  // Plancher de 60 px par colonne : une largeur absurde (mesure à zéro pendant
  // une transition) ne doit pas produire de vignette négative.
  final available = math.max(
    columns * 60.0,
    width - (padding ?? RiftSpace.page.horizontal),
  );
  final tileWidth = (available - gap * (columns - 1)) / columns;
  return CardGridMetrics(
    columns: columns,
    tileWidth: tileWidth,
    imageHeight: tileWidth / CardImage.portraitRatio,
  );
}
