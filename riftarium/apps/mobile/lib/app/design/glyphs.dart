import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Glyphes officiels Riot (`:rb_energy_3:`, `:rb_rune_fury:`, `:rb_might:`),
/// servis en SVG par le CDN et dessinés dans le texte des cartes comme des
/// règles. Un seul endroit pour les connaître : les shortcodes, leurs
/// abréviations (`[R]`, `[1]`, `[E]`), leurs libellés et leur rendu.
///
/// Le jeu de glyphes est minuscule (une trentaine de fichiers de quelques
/// centaines d'octets) : un cache mémoire suffit. Quand le SVG manque
/// (hors ligne, CDN muet), on affiche l'abréviation du texte officiel plutôt
/// qu'un vide : les règles se lisent sans réseau.

/// Base des glyphes : les noms de fichiers reprennent exactement les
/// raccourcis `:rb_…:` du texte des cartes.
const String kGlyphBase =
    'https://assetcdn.rgpub.io/public/live/riot-shared/'
    'player-experiences/riot-glyphs/rb/latest';

String glyphUrl(String token) => '$kGlyphBase/$token.svg';

/// Abréviations du texte officiel → shortcode complet.
const Map<String, String> kShortTokens = {
  'R': 'rune_fury',
  'G': 'rune_calm',
  'B': 'rune_mind',
  'O': 'rune_body',
  'P': 'rune_chaos',
  'Y': 'rune_order',
  'C': 'rune_rainbow',
  'E': 'exhaust',
  'M': 'might',
};

/// Index inverse : shortcode → abréviation, pour le repli textuel.
final Map<String, String> kTokenShorts = {
  for (final entry in kShortTokens.entries) entry.value: entry.key,
};

/// Runes connues (les six domaines plus la rune libre).
const List<String> kRunes = [
  'fury',
  'calm',
  'mind',
  'body',
  'chaos',
  'order',
  'rainbow',
];

const Map<String, String> kRuneLabels = {
  'fury': 'Rune de Fureur',
  'calm': 'Rune de Calme',
  'mind': 'Rune d’Esprit',
  'body': 'Rune de Corps',
  'chaos': 'Rune de Chaos',
  'order': 'Rune d’Ordre',
  'rainbow': 'Rune libre',
};

/// Nature d'un glyphe : elle décide de sa teinte à l'affichage.
enum GlyphKind {
  /// Puissance, épuisement : silhouette blanche à recolorer en encre.
  ink,

  /// Pastille d'énergie : Riot la sert claire, on l'inverse comme le site
  /// (`filter: invert(1) saturate(0)` sur `.rb-glyph.energy`).
  energy,

  /// Rune de domaine : déjà colorée, laissée telle quelle.
  rune,
}

/// Ce qu'il faut savoir d'un glyphe pour le dessiner : son shortcode, son
/// libellé accessible, sa teinte et son abréviation de repli.
class RiftGlyphSpec {
  const RiftGlyphSpec({
    required this.token,
    required this.label,
    required this.kind,
    required this.short,
  });

  final String token;
  final String label;
  final GlyphKind kind;

  /// Repli affiché quand le SVG n'est pas disponible (« [R] », « [2] »).
  final String short;

  String get url => glyphUrl(token);

  /// Glyphe d'un shortcode, ou `null` si le raccourci est inconnu : l'appelant
  /// le laisse alors lisible en clair plutôt que de l'effacer.
  static RiftGlyphSpec? parse(String token) {
    if (token == 'might' || token == 'exhaust') {
      return RiftGlyphSpec(
        token: token,
        label: token == 'might' ? 'Puissance' : 'Épuisement',
        kind: GlyphKind.ink,
        short: '[${kTokenShorts[token]}]',
      );
    }
    if (token.startsWith('energy_')) {
      final amount = token.substring('energy_'.length);
      return RiftGlyphSpec(
        token: token,
        label: 'Énergie $amount',
        kind: GlyphKind.energy,
        short: '[$amount]',
      );
    }
    if (token.startsWith('rune_')) {
      final domain = token.substring('rune_'.length);
      if (kRunes.contains(domain)) {
        return RiftGlyphSpec(
          token: token,
          label: kRuneLabels[domain] ?? 'Rune',
          kind: GlyphKind.rune,
          short: '[${kTokenShorts[token] ?? '·'}]',
        );
      }
    }
    return null;
  }
}

/// Glyphe officiel dessiné dans une ligne de texte.
class RiftGlyph extends StatelessWidget {
  const RiftGlyph({
    super.key,
    required this.glyph,
    this.size = 18,
    this.color,
    this.fallbackStyle,
  });

  final RiftGlyphSpec glyph;
  final double size;

  /// Teinte des glyphes d'encre (puissance, épuisement) : la couleur du texte.
  final Color? color;

  /// Style du repli textuel : celui du texte porteur, par défaut.
  final TextStyle? fallbackStyle;

  @override
  Widget build(BuildContext context) {
    final styles = riftText(context);
    final ink = color ?? styles.ink;
    // Le repli tient dans le carré du glyphe : `FittedBox` le réduit.
    final fallback = FittedBox(
      child: Text(
        glyph.short,
        style: (fallbackStyle ?? styles.small).copyWith(color: ink),
      ),
    );
    return Semantics(
      label: glyph.label,
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<Uint8List?>(
          future: GlyphStore.load(glyph.url),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) return fallback;
            return SvgPicture.memory(
              bytes,
              width: size,
              height: size,
              colorFilter: _filterOf(glyph.kind, ink),
              placeholderBuilder: (context) => fallback,
            );
          },
        ),
      ),
    );
  }

  static ColorFilter? _filterOf(GlyphKind kind, Color ink) => switch (kind) {
    GlyphKind.ink => ColorFilter.mode(ink, BlendMode.srcIn),
    // Riot sert la pastille d'énergie claire ; on l'inverse (disque sombre,
    // chiffre clair) comme le site le fait sur `.rb-glyph.energy`.
    GlyphKind.energy => _invert,
    GlyphKind.rune => null,
  };

  /// Désaturation puis inversion : `filter: invert(1) saturate(0)`.
  static const ColorFilter _invert = ColorFilter.matrix(<double>[
    -0.2126, -0.7152, -0.0722, 0, 255, //
    -0.2126, -0.7152, -0.0722, 0, 255, //
    -0.2126, -0.7152, -0.0722, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);
}

/// Téléchargement et mémorisation des glyphes SVG.
abstract final class GlyphStore {
  static final Map<String, Future<Uint8List?>> _cache = {};

  static final Dio _dio = Dio(
    BaseOptions(
      responseType: ResponseType.bytes,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// Octets du glyphe, ou `null` si le CDN n'a pas répondu : un glyphe
  /// manquant ne doit jamais empêcher de lire un texte.
  ///
  /// Un échec n'est pas mémorisé : l'entrée est retirée du cache pour que le
  /// glyphe reparte au prochain affichage (réseau revenu, CDN rétabli).
  static Future<Uint8List?> load(String url) =>
      _cache.putIfAbsent(url, () async {
        try {
          final response = await _dio.get<List<int>>(url);
          final data = response.data;
          if (data == null) {
            _forget(url);
            return null;
          }
          return Uint8List.fromList(data);
        } on DioException {
          _forget(url);
          return null;
        }
      });

  /// Oublie une entrée en échec. `remove` rend le `Future` mémorisé, dont on
  /// n'a que faire ici : c'est bien le résultat que l'on jette.
  static void _forget(String url) => unawaited(_cache.remove(url));
}
