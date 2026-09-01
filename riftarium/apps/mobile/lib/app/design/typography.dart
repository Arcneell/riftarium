import 'package:flutter/painting.dart';

import 'tokens.dart';

/// Trois voix, comme sur le site : Cinzel pour les titres (capitales
/// épigraphiques — les bas-de-casse sortent en petites capitales, c'est
/// voulu), Outfit pour tout le texte, IBM Plex Mono pour ce qui se lit comme
/// une donnée (codes de carte, prix, quantités).
abstract final class RiftFonts {
  static const display = 'Cinzel';
  static const body = 'Outfit';
  static const mono = 'IBMPlexMono';

  /// Outfit et Cinzel sont des polices variables : le poids passe par l'axe
  /// `wght`, pas par `fontWeight` seul (qui ne sélectionnerait qu'un fichier
  /// statique).
  static List<FontVariation> weight(double value) => [
    FontVariation('wght', value),
  ];
}

/// Échelle typographique. `ink` = couleur du texte courant, `muted` = secondaire.
/// Les titres sont toujours champagne (`RiftColors.inkStrong`) : le thème est
/// unique, nuit de Piltover.
class RiftTextStyles {
  const RiftTextStyles({required this.ink, required this.muted});

  final Color ink;
  final Color muted;

  TextStyle get displayLarge => TextStyle(
    fontFamily: RiftFonts.display,
    fontVariations: RiftFonts.weight(500),
    fontSize: 29,
    height: 1.12,
    letterSpacing: 0.4,
    color: RiftColors.inkStrong,
  );

  TextStyle get displayMedium => TextStyle(
    fontFamily: RiftFonts.display,
    fontVariations: RiftFonts.weight(500),
    fontSize: 22,
    height: 1.16,
    letterSpacing: 0.3,
    color: RiftColors.inkStrong,
  );

  TextStyle get displaySmall => TextStyle(
    fontFamily: RiftFonts.display,
    fontVariations: RiftFonts.weight(500),
    fontSize: 17.5,
    height: 1.2,
    letterSpacing: 0.2,
    color: RiftColors.inkStrong,
  );

  TextStyle get title => TextStyle(
    fontFamily: RiftFonts.body,
    fontVariations: RiftFonts.weight(600),
    fontSize: 17,
    height: 1.3,
    color: ink,
  );

  TextStyle get body => TextStyle(
    fontFamily: RiftFonts.body,
    fontVariations: RiftFonts.weight(400),
    fontSize: 15.5,
    height: 1.5,
    color: ink,
  );

  TextStyle get bodyStrong =>
      body.copyWith(fontVariations: RiftFonts.weight(600));

  TextStyle get small => TextStyle(
    fontFamily: RiftFonts.body,
    fontVariations: RiftFonts.weight(400),
    fontSize: 13.5,
    height: 1.4,
    color: muted,
  );

  /// Sur-titre en capitales espacées (« Commencer ici », « Cartothèque »).
  TextStyle get eyebrow => TextStyle(
    fontFamily: RiftFonts.mono,
    fontSize: 11,
    letterSpacing: 1.6,
    height: 1.2,
    color: RiftColors.gold,
  );

  /// Codes, prix, quantités.
  TextStyle get mono => TextStyle(
    fontFamily: RiftFonts.mono,
    fontSize: 12.5,
    letterSpacing: 0.6,
    height: 1.3,
    color: muted,
  );

  TextStyle get monoStrong =>
      mono.copyWith(fontWeight: FontWeight.w600, color: ink);
}
