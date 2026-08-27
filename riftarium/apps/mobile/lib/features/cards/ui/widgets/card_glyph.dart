import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme.dart';
import '../../domain/card_text.dart';

/// Glyphe officiel Riot (`:rb_energy_3:`, `:rb_rune_fury:`, `:rb_might:`),
/// servi en SVG par le CDN et dessiné dans le texte d'une carte.
///
/// Le jeu de glyphes est minuscule (une trentaine de fichiers de quelques
/// centaines d'octets) : un cache mémoire suffit, et l'échec d'un
/// téléchargement laisse simplement un vide plutôt que de casser le texte.
class CardGlyph extends StatelessWidget {
  const CardGlyph({super.key, required this.glyph, this.size = 18, this.color});

  final CardTextGlyph glyph;
  final double size;

  /// Teinte des glyphes d'encre (puissance, épuisement) : la couleur du texte.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? riftText(context).ink;
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
            if (bytes == null) return const SizedBox.shrink();
            return SvgPicture.memory(
              bytes,
              width: size,
              height: size,
              colorFilter: _filterOf(glyph.kind, ink),
              placeholderBuilder: (context) => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }

  static ColorFilter? _filterOf(GlyphKind kind, Color ink) => switch (kind) {
    GlyphKind.ink => ColorFilter.mode(ink, BlendMode.srcIn),
    // Riot sert la pastille d'énergie claire ; sur parchemin, on l'inverse
    // (disque sombre, chiffre clair) comme le fait le site.
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
  /// manquant ne doit jamais empêcher de lire le texte d'une carte.
  static Future<Uint8List?> load(String url) =>
      _cache.putIfAbsent(url, () async {
        try {
          final response = await _dio.get<List<int>>(url);
          final data = response.data;
          return data == null ? null : Uint8List.fromList(data);
        } catch (_) {
          return null;
        }
      });
}
