import '../../../app/design/glyphs.dart';

/// Ce que le texte d'une carte a de particulier : le coût en pouvoir, qui se
/// lit en runes du domaine de la carte. Le découpage du texte enrichi
/// lui-même (mots-clés, glyphes, gras) vit dans `app/design/rich_text.dart`,
/// partagé avec les règles.

/// Rune correspondant à un domaine (`Fury` → `rune_fury`).
const Map<String, String> kDomainRune = {
  'Fury': 'fury',
  'Calm': 'calm',
  'Mind': 'mind',
  'Body': 'body',
  'Chaos': 'chaos',
  'Order': 'order',
  'Colorless': 'rainbow',
};

/// Runes du coût en pouvoir : autant de runes du premier domaine que de points.
List<RiftGlyphSpec> powerRunes(List<String> domains, int? power) {
  final count = power ?? 0;
  if (count < 1) return const [];
  final rune = kDomainRune[domains.isEmpty ? '' : domains.first] ?? 'rainbow';
  final glyph = RiftGlyphSpec.parse('rune_$rune');
  if (glyph == null) return const [];
  return List.filled(count, glyph);
}
