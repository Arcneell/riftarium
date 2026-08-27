import 'package:flutter/painting.dart';

import 'tokens.dart';

/// Trois voix, comme sur le site : Marcellus pour les titres (capitales
/// romaines, un peu solennel), Outfit pour tout le texte, IBM Plex Mono pour ce
/// qui se lit comme une donnée (codes de carte, prix, quantités).
abstract final class RiftFonts {
  static const display = 'Marcellus';
  static const body = 'Outfit';
  static const mono = 'IBMPlexMono';

  /// Outfit est une police variable : le poids passe par l'axe `wght`, pas par
  /// `fontWeight` seul (qui ne sélectionnerait qu'un fichier statique).
  static List<FontVariation> weight(double value) => [
    FontVariation('wght', value),
  ];
}

/// Échelle typographique. `ink` = couleur du texte courant, `muted` = secondaire.
class RiftTextStyles {
  const RiftTextStyles({required this.ink, required this.muted});

  final Color ink;
  final Color muted;

  TextStyle get displayLarge => TextStyle(
    fontFamily: RiftFonts.display,
    fontSize: 34,
    height: 1.1,
    letterSpacing: 0.2,
    color: ink,
  );

  TextStyle get displayMedium => TextStyle(
    fontFamily: RiftFonts.display,
    fontSize: 26,
    height: 1.15,
    color: ink,
  );

  TextStyle get displaySmall => TextStyle(
    fontFamily: RiftFonts.display,
    fontSize: 20,
    height: 1.2,
    color: ink,
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
