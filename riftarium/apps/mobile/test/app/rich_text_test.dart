import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/design/glyphs.dart';
import 'package:riftarium_mobile/app/design/rich_text.dart';
import 'package:riftarium_mobile/app/theme.dart';
import 'package:riftarium_mobile/features/cards/domain/card_text.dart';

/// Découpage et rendu du texte enrichi, commun aux cartes et aux règles
/// (ex-`card_text_test.dart` et `rule_rich_text_test.dart`).
void main() {
  group('parseRiftText — texte des cartes', () {
    List<RiftTextPart> parse(String? text) =>
        parseRiftText(text, breakGluedAbilities: true);

    test('un texte sans marqueur reste d’un seul tenant', () {
      final parts = parse('Quand Jinx arrive, infligez 2 dégâts.');

      expect(parts, hasLength(1));
      expect(
        (parts.single as RiftTextRun).value,
        'Quand Jinx arrive, infligez 2 dégâts.',
      );
    });

    test('les crochets deviennent des mots-clés, avec leur famille', () {
      final parts = parse('[Action] Piochez une carte. [Bouclier 2]');

      final keywords = parts.whereType<RiftTextKeyword>().toList();
      expect(keywords.map((k) => k.label), ['Action', 'Bouclier 2']);
      expect(keywords.first.family, KeywordFamily.timing);
      // « Bouclier » est l'alias français de `shield`.
      expect(keywords.last.family, KeywordFamily.combat);
    });

    test('le chevron pointe le mot-clé qui précède', () {
      final parts = parse('[Réaction][>]Défaussez une carte.');

      final keyword = parts.whereType<RiftTextKeyword>().single;
      expect(keyword.label, 'Réaction');
      expect(keyword.arrow, isTrue);
    });

    test('les raccourcis :rb_…: deviennent des glyphes typés', () {
      final parts = parse(':rb_energy_3: puis :rb_rune_fury: :rb_might:');

      final glyphs = parts.whereType<RiftTextGlyph>().toList();
      expect(glyphs.map((g) => g.glyph.kind), [
        GlyphKind.energy,
        GlyphKind.rune,
        GlyphKind.ink,
      ]);
      expect(glyphs.first.glyph.url, endsWith('/energy_3.svg'));
      expect(glyphs[1].glyph.label, 'Rune de Fureur');
    });

    test('un raccourci inconnu reste lisible dans le texte', () {
      final parts = parse('Coût :rb_inconnu: réduit');

      expect(parts, hasLength(1));
      expect((parts.single as RiftTextRun).value, contains(':rb_inconnu:'));
    });

    test('« NO TEXT » et les entités HTML sont nettoyés', () {
      expect(parse('[NO TEXT]'), isEmpty);
      expect(
        (parse('2 &gt; 1 &amp; c’est tout').single as RiftTextRun).value,
        '2 > 1 & c’est tout',
      );
    });

    test('un texte vide ne produit aucun morceau', () {
      expect(parse(null), isEmpty);
      expect(parse(''), isEmpty);
    });

    test('deux capacités collées sont séparées', () {
      final parts = parse('…Amplifié.)[Amplifié] Piochez.');

      expect((parts.first as RiftTextRun).value, endsWith('\n'));
      expect(parts.whereType<RiftTextKeyword>().single.label, 'Amplifié');
    });
  });

  group('parseRiftText — texte des règles', () {
    List<RiftTextPart> parse(String text) =>
        parseRiftText(text, markdownBold: true, shortTokens: true);

    test('le texte simple donne un seul morceau', () {
      final parts = parse('Une unité se déplace.');
      expect(parts.single, isA<RiftTextRun>());
      expect(parts.single.bold, isFalse);
      expect((parts.single as RiftTextRun).value, 'Une unité se déplace.');
    });

    test('les doubles astérisques marquent le gras', () {
      final parts = parse('Phase **d’éveil** : redressez.');
      expect(parts.whereType<RiftTextRun>().map((p) => p.value), [
        'Phase ',
        'd’éveil',
        ' : redressez.',
      ]);
      expect(parts.map((p) => p.bold), [false, true, false]);
    });

    test('les crochets deviennent des mots-clés, avec leur famille', () {
      final parts = parse('Jouez une [Réaction] puis un [Assaut 2].');
      final keywords = parts.whereType<RiftTextKeyword>().toList();
      expect(keywords.map((k) => k.label), ['Réaction', 'Assaut 2']);
      // Familles relevées sur les cartes : timing pour Réaction, combat pour
      // Assaut (le chiffre ne change pas la famille).
      expect(keywords.map((k) => k.family), [
        KeywordFamily.timing,
        KeywordFamily.combat,
      ]);
    });

    test('un mot-clé suivi de [>] se termine en pointe', () {
      final parts = parse('[Agonie][>] Piochez.');
      final keyword = parts.first as RiftTextKeyword;
      expect(keyword.family, KeywordFamily.state);
      expect(keyword.arrow, isTrue);
      expect(parts.length, 2);
    });

    test('« NO TEXT » disparaît', () {
      expect(parse('[NO TEXT]'), isEmpty);
    });

    test('les shortcodes deviennent des glyphes', () {
      final parts = parse('Payez :rb_energy_2: et :rb_rune_fury:.');
      final glyphs = parts.whereType<RiftTextGlyph>().toList();
      expect(glyphs.map((g) => g.glyph.token), ['energy_2', 'rune_fury']);
      expect(glyphs.map((g) => g.glyph.label), ['Énergie 2', 'Rune de Fureur']);
      // Repli affiché quand le SVG ne se charge pas.
      expect(glyphs.map((g) => g.glyph.short), ['[2]', '[R]']);
    });

    test('les abréviations du texte officiel donnent les mêmes glyphes', () {
      final parts = parse('Coût [1][R], puis [E] et [M].');
      final glyphs = parts.whereType<RiftTextGlyph>().toList();
      expect(glyphs.map((g) => g.glyph.token), [
        'energy_1',
        'rune_fury',
        'exhaust',
        'might',
      ]);
      expect(
        glyphs
            .where((g) => g.glyph.kind == GlyphKind.ink)
            .map((g) => g.glyph.token),
        ['exhaust', 'might'],
      );
    });

    test('un shortcode inconnu reste du texte', () {
      final parts = parse('Voir :rb_inconnu: ici.');
      expect(parts.single, isA<RiftTextRun>());
      expect((parts.single as RiftTextRun).value, 'Voir :rb_inconnu: ici.');
    });

    test('gras et mot-clé se combinent', () {
      final parts = parse('**Une [Vision] forte**');
      expect(parts.every((part) => part.bold), isTrue);
      expect(parts[1], isA<RiftTextKeyword>());
    });

    test('sans le drapeau, une abréviation reste un mot-clé', () {
      final parts = parseRiftText('[R]');
      expect(parts.whereType<RiftTextKeyword>().single.label, 'R');
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

  group('RiftRichText', () {
    Widget host(Widget child) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: child),
    );

    testWidgets('le rendu affiche le texte et la pastille du mot-clé', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const RiftRichText(
            'Jouez une [Réaction] **maintenant**.',
            markdownBold: true,
            shortTokens: true,
          ),
        ),
      );
      await tester.pump();

      // Le mot-clé est une pastille : capitales, hors du flux de texte.
      expect(find.text('RÉACTION'), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('le glyphe retombe sur son abréviation sans SVG', (
      tester,
    ) async {
      // Aucun réseau en test : le CDN ne répond pas, le texte doit rester
      // lisible (les règles se consultent hors ligne).
      await tester.pumpWidget(
        host(
          const RiftRichText(
            'Payez [1][R].',
            markdownBold: true,
            shortTokens: true,
          ),
        ),
      );
      // Laisse le téléchargement échouer (client HTTP simulé) : sans cela,
      // le minuteur de dio reste en attente à la fin du test.
      await tester.pumpAndSettle();

      expect(find.text('[1]'), findsOneWidget);
      expect(find.text('[R]'), findsOneWidget);
    });
  });
}
