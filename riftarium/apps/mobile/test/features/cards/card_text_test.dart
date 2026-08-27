import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/cards/domain/card_text.dart';

void main() {
  group('parseCardText', () {
    test('un texte sans marqueur reste d’un seul tenant', () {
      final parts = parseCardText('Quand Jinx arrive, infligez 2 dégâts.');

      expect(parts, hasLength(1));
      expect(
        (parts.single as CardTextRun).value,
        'Quand Jinx arrive, infligez 2 dégâts.',
      );
    });

    test('les crochets deviennent des mots-clés, avec leur famille', () {
      final parts = parseCardText('[Action] Piochez une carte. [Bouclier 2]');

      final keywords = parts.whereType<CardTextKeyword>().toList();
      expect(keywords.map((k) => k.label), ['Action', 'Bouclier 2']);
      expect(keywords.first.family, KeywordFamily.timing);
      // « Bouclier » est l'alias français de `shield`.
      expect(keywords.last.family, KeywordFamily.combat);
    });

    test('le chevron pointe le mot-clé qui précède', () {
      final parts = parseCardText('[Réaction][>]Défaussez une carte.');

      final keyword = parts.whereType<CardTextKeyword>().single;
      expect(keyword.label, 'Réaction');
      expect(keyword.arrow, isTrue);
    });

    test('les raccourcis :rb_…: deviennent des glyphes typés', () {
      final parts = parseCardText(
        ':rb_energy_3: puis :rb_rune_fury: :rb_might:',
      );

      final glyphs = parts.whereType<CardTextGlyph>().toList();
      expect(glyphs.map((g) => g.kind), [
        GlyphKind.energy,
        GlyphKind.rune,
        GlyphKind.ink,
      ]);
      expect(glyphs.first.url, endsWith('/energy_3.svg'));
      expect(glyphs[1].label, 'Rune de Fureur');
    });

    test('un raccourci inconnu reste lisible dans le texte', () {
      final parts = parseCardText('Coût :rb_inconnu: réduit');

      expect(parts, hasLength(1));
      expect((parts.single as CardTextRun).value, contains(':rb_inconnu:'));
    });

    test('« NO TEXT » et les entités HTML sont nettoyés', () {
      expect(parseCardText('[NO TEXT]'), isEmpty);
      expect(
        (parseCardText('2 &gt; 1 &amp; c’est tout').single as CardTextRun)
            .value,
        '2 > 1 & c’est tout',
      );
    });

    test('un texte vide ne produit aucun morceau', () {
      expect(parseCardText(null), isEmpty);
      expect(parseCardText(''), isEmpty);
    });
  });

  group('powerRunes', () {
    test('autant de runes que de points de pouvoir, du premier domaine', () {
      final runes = powerRunes(const ['Calm', 'Mind'], 2);

      expect(runes, hasLength(2));
      expect(runes.first.token, 'rune_calm');
      expect(runes.first.kind, GlyphKind.rune);
    });

    test('sans pouvoir, aucune rune', () {
      expect(powerRunes(const ['Fury'], 0), isEmpty);
      expect(powerRunes(const ['Fury'], null), isEmpty);
    });

    test('sans domaine, la rune libre', () {
      expect(powerRunes(const [], 1).single.token, 'rune_rainbow');
    });
  });
}
